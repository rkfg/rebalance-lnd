import sys

import fmt
from routes import Routes

DEFAULT_BASE_FEE_SAT_MSAT = 1000
DEFAULT_FEE_RATE_MSAT = 0.001


def debug(message):
    sys.stderr.write(message + "\n")


def debugnobreak(message):
    sys.stderr.write(message)


class Logic:
    def __init__(self, lnd, first_hop_channel, last_hop_channel, amount, channel_ratio, excluded, max_fee_factor, deep, path):
        self.lnd = lnd
        self.first_hop_channel = first_hop_channel
        self.last_hop_channel = last_hop_channel
        self.amount = amount
        self.channel_ratio = channel_ratio
        self.excluded = []
        if excluded:
            self.excluded = excluded
        self.max_fee_factor = max_fee_factor
        self.deep = deep
        self.path = path

    def rebalance(self):
        if self.last_hop_channel:
            debug("Ⓘ Sending " + fmt.col_hi("{:,}".format(self.amount)) + " satoshis to rebalance to channel with ID %s"
                   % fmt.col_lo(fmt.print_chanid(self.last_hop_channel.chan_id)))
        else:
            debug("Ⓘ Sending " + fmt.col_hi("{:,}".format(self.amount)) + " satoshis.")
        if self.channel_ratio != 0.5:
            debug("Ⓘ Channel ratio used is " + fmt.col_hi("%d%%" % int(self.channel_ratio * 100)))
        if self.first_hop_channel:
            debug("Ⓘ Forced first channel has ID %s" % fmt.col_lo(fmt.print_chanid(self.first_hop_channel.chan_id)))

        payment_request = self.generate_invoice()

        if self.path:
            myroute = self.lnd.build_route(self.path, self.amount, self.first_hop_channel.chan_id)
            if isinstance(myroute, Exception):
                debug("")
                debug(fmt.col_err("✘ " + myroute.details()))
                return False
            success = self.try_route(payment_request, myroute, [myroute], [])
            if success:
                return True
        else:
            routes = Routes(self.lnd, payment_request, self.first_hop_channel, self.last_hop_channel, self.deep)

            self.initialize_ignored_channels(routes)

            tried_routes = []
            while routes.has_next():
                route = routes.get_next()

                success = self.try_route(payment_request, route, routes, tried_routes)
                if success:
                    return True
        debug("")
        debug(fmt.col_err("✘ Could not find any suitable route"))
        return False

    def try_route(self, payment_request, route, routes, tried_routes):
        if self.route_is_invalid(route, routes):
            return False

        tried_routes.append(route)
        debug("")
        debug("Ⓘ Trying route #%d" % len(tried_routes))
        debug(fmt.print_route(route,self.lnd))

        response = self.lnd.send_payment(payment_request, route)
        is_successful = response.failure.code == 0
        if is_successful:
            debug("")
            debug(fmt.col_hi("✔ Success!") + " Paid fees: %s sat (%s msat)" % 
                (fmt.col_hi(route.total_fees), route.total_fees_msat))
            debug("")
            return True
        else:
            self.handle_error(response, route, routes)
            return False

    @staticmethod
    def handle_error(response, route, routes):
        code = response.failure.code
        failure_source_pubkey = Logic.get_failure_source_pubkey(response, route)
        if code == 15:
            debugnobreak("Ⓔ Temporary channel failure, ")
            routes.ignore_edge_on_route(failure_source_pubkey, route)
        elif code == 18:
            debugnobreak("Ⓔ Unknown next peer, ")
            routes.ignore_edge_on_route(failure_source_pubkey, route)
        elif code == 12:
            debugnobreak("Ⓔ Fee insufficient, ")
            routes.ignore_edge_on_route(failure_source_pubkey, route)
        elif code == 14:
            debugnobreak("Ⓔ Channel disabled, ")
            routes.ignore_edge_on_route(failure_source_pubkey, route)
        else:
            debug(repr(response))
            debug("Ⓔ Unknown error code %s" % repr(code))

    @staticmethod
    def get_failure_source_pubkey(response, route):
        if response.failure.failure_source_index == 0:
            failure_source_pubkey = route.hops[-1].pub_key
        else:
            failure_source_pubkey = route.hops[response.failure.failure_source_index - 1].pub_key
        return failure_source_pubkey

    def route_is_invalid(self, route, routes):
        first_hop = route.hops[0]
        last_hop = route.hops[-1]
        if self.low_local_ratio_after_sending(first_hop, route.total_amt):
            debugnobreak("Low local ratio after sending, ")
            routes.ignore_first_hop(self.get_channel_for_channel_id(first_hop.chan_id))
            return True
        if first_hop.chan_id == last_hop.chan_id:
            debugnobreak("First hop and last hop use same channel, ")
            hop_before_last_hop = route.hops[-2]
            routes.ignore_edge_from_to(last_hop.chan_id, hop_before_last_hop.pub_key, last_hop.pub_key)
            return True
        if self.fees_too_high(route):
            routes.ignore_edge_with_highest_fee(route)
            return True
        return False

    def low_local_ratio_after_sending(self, first_hop, total_amount):
        if self.first_hop_channel:
            # Just use the computed/specified amount to drain the first hop, ignoring fees
            return False
        channel_id = first_hop.chan_id
        channel = self.get_channel_for_channel_id(channel_id)

        remote = channel.remote_balance + total_amount
        local = channel.local_balance - total_amount
        ratio = float(local) / (remote + local)
        return ratio < self.channel_ratio

    def fees_too_high(self, route):
        hops_with_fees = len(route.hops) - 1
        lnd_fees = hops_with_fees * (DEFAULT_BASE_FEE_SAT_MSAT + (self.amount * DEFAULT_FEE_RATE_MSAT))
        limit = self.max_fee_factor * lnd_fees
        return route.total_fees_msat > limit

    def generate_invoice(self):
        if self.last_hop_channel:
            memo = "Rebalance of channel with ID %d" % self.last_hop_channel.chan_id
        else:
            memo = "Rebalance of channel with ID %d" % self.first_hop_channel.chan_id
        return self.lnd.generate_invoice(memo, self.amount)

    def get_channel_for_channel_id(self, channel_id):
        for channel in self.lnd.get_channels():
            if channel.chan_id == channel_id:
                if not hasattr(channel, 'local_balance'):
                    channel.local_balance = 0
                if not hasattr(channel, 'remote_balance'):
                    channel.remote_balance = 0
                return channel

    def initialize_ignored_channels(self, routes):
        for channel in self.lnd.get_channels():
            if self.low_local_ratio_after_sending(channel, self.amount):
                routes.ignore_first_hop(channel, show_message=False)
            if channel.chan_id in self.excluded:
                debugnobreak("Channel is excluded, ")
                routes.ignore_first_hop(channel)

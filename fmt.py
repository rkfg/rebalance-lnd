def lnd_to_cl_scid(s):
    block = s >> 40
    tx = s >> 16 & 0xFFFFFF
    output = s  & 0xFFFF
    return (block, tx, output)

def cl_to_lnd_scid(s):
    s = [int(i) for i in s.split(':')]
    return (s[0] << 40) | (s[1] << 16) | s[2]

def x_to_lnd_scid(s):
    s = [int(i) for i in s.split('x')]
    return (s[0] << 40) | (s[1] << 16) | s[2]

def parse_channel_id(s):
    if s == None:
        return None
    if ':' in s:
        return int(cl_to_lnd_scid(s))
    if 'x' in s:
        return int(x_to_lnd_scid(s))
    return int(s)

def print_route(route, lnd):
    route_str = " -> ".join( ("%s %s" % (print_chanid(h.chan_id), print_node(lnd.get_node_info(h.pub_key)) ) ) for h in route.hops)
    return route_str

def print_node(node_info):
    node_str = "[%s]" % "|".join([node_info.node.alias,str(node_info.num_channels),str(node_info.total_capacity)])
    return node_str
        
def print_chanid(chan_id):
    return "%sx%sx%s" % lnd_to_cl_scid(chan_id)

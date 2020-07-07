FROM python:3-slim

ENV GRPC_LOCATION=127.0.0.1:10009
ENV LND_DIR=~/.lnd

WORKDIR /app/

COPY requirements.txt .

RUN pip install -r requirements.txt

COPY . .

ENTRYPOINT /app/rebalance.py --grpc ${GRPC_LOCATION} --lnddir ${LND_DIR} "$@"
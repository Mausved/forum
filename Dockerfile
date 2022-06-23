FROM golang:latest AS builder

COPY api/ /var/www/service/api/
COPY go.mod /var/www/service/go.mod
COPY go.sum /var/www/service/go.sum
WORKDIR /var/www/service/
RUN go install github.com/swaggo/swag/cmd/swag@latest && swag init -g api/cmd/main.go
RUN GOAMD64=v3 go build -ldflags "-w -s" -o api/cmd/main api/cmd/main.go

FROM ubuntu:20.04

RUN apt-get -y update && apt-get install -y tzdata
RUN ln -snf /usr/share/zoneinfo/Russia/Moscow /etc/localtime && echo Russia/Moscow > /etc/timezone

RUN apt-get -y update && apt-get install -y postgresql-12 && rm -rf /var/lib/apt/lists/*
USER postgres

RUN /etc/init.d/postgresql start && \
  psql --command "CREATE USER root WITH SUPERUSER PASSWORD 'admin';" && \
  createdb -O root forum_db && \
  /etc/init.d/postgresql stop

WORKDIR /cmd

COPY ./db/db.sql ./db.sql

COPY --from=builder /var/www/service/api/cmd/main .


EXPOSE 5000
ENV PGPASSWORD admin
ENV PGUSER root
ENV PGHOST localhost
ENV PGDB forum_db

ENV dsn user=$PGUSER password=$PGPASSWORD dbname=$PGDB host=$PGHOST port=5432 sslmode=disable
ENV port "5000"
ENV dbType postgres

USER $PGUSER
CMD service postgresql start && psql -h $PGHOST -d $PGDB -U $PGUSER -p 5432 -a -q -f ./db.sql && ./main

# Postgres-O-Matic

This repository is a demo of a Heroku Add-on written with Ruby/Sinatra

It is designed to create shared postgresql databases as a cloud service.
It is for demonstration purposes only and not meant to be a production system.

## Usage
  
    clone
    $ gem install kensa
    $ gem install foreman
    $ kensa init --foreman
    $ foreman start

## Connect to a database

    $ add DATABASE_URL to .env file

## Make a new postgres !

    $ kensa test provision

## Make some tables and sign in

    $ kensa run ./consumer.rb

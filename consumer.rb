#!/usr/bin/env ruby

require 'bundler'
Bundler.require

DB = Sequel.connect ENV["MYADDON_URL"].to_s

[:foo, :bar, :baz].each do |table| 
  DB.create_table table do
    primary_key :id
    String :name
  end
end

id = ENV['MYADDON_URL'].split("/").reverse.first
fork { exec "kensa sso #{id}" }
gets

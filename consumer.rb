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


# ruby kung foo to see the sso page for the demo
id = ENV['MYADDON_URL'].split("/").reverse.first
fork { exec "kensa sso #{id}" }
# wait till i'm done...
gets

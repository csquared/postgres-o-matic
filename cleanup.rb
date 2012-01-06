#!/usr/bin/env ruby

require 'bundler'
Bundler.require 
require 'foreman'
Foreman.load_env!

DB = Sequel.connect ENV['DATABASE_URL'].to_s

DB[:resources].select.each do |resource|
  puts "drop #{resource[:id]}"
  DB << "DROP DATABASE #{resource[:id]}" rescue nil
end

DB[:resources].truncate

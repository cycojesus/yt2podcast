#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'fileutils'
require 'open-uri'
require 'optparse'
require 'rss'

require 'youtube-dl.rb'
require 'taglib'

config = { 'root_url': 'http://yt2podcast.le-moine.org/',
           'download_root_path': '/home/cycojesus/www/yt2podcast/feeds' }

def youtubedl( url, output_file, ogg_file )
  begin
    YoutubeDL.get( url,
                   output: output_file,
                   extract_audio: true,
                   audio_format: 'vorbis',
                   audio_quality: 0 ) unless File.exist? ogg_file
  rescue
    STDERR.puts "Couldn't retrieve video #{url}"
  end
end

def tag( entry, filename )
  TagLib::FileRef.open( filename ) do |file|
    tag = file.tag
    
    tag.artist = entry.author.name.content
    tag.title = entry.title.content
    
    file.save
  end
end

def convert_feed( url, config )
  feed = RSS::Parser.parse( open( url ), false )
  
  name = feed.author.name.content
  STDOUT.puts name
  
  feed_dir = "#{config[ 'download_root_path' ]}/#{name.tr( ' ', '_' )}"
  dl_dir = "#{feed_dir}/medias"
  FileUtils.mkdir_p( dl_dir ) unless Dir.exist?( dl_dir )
  
  feed.entries
      .each do |entry| 
    video_id = entry.link.href.gsub( 'http://www.youtube.com/watch?v=', '' )
    output_file = "#{dl_dir}/#{video_id}.tmp"
    ogg_file = "#{dl_dir}/#{video_id}.ogg"
    STDOUT.puts " 🠖 #{video_id}"
    
    youtubedl( entry.link.href, output_file, ogg_file )
    
    if File.exist?( ogg_file )
      tag( entry, ogg_file )
      
      entry.link.href = "#{config['root_url']}/#{name}/medias/#{video_id}.ogg"
    end
  end
  
  feed.updated = Time.now
  
  File.open( "#{feed_dir}/feed.xml", 'w' ) do |feed_file| 
    feed_file.write( feed.to_atom( 'feed' ).to_s )
  end
end

feeds = []
# opml = nil
ARGV.options do |opts|
  #/ Usage: <progname> [options]...
  #/ How does this script make my life easier?
  opts.on( '-u', '--url=val', String ) { |val| config['root_url'] = val }
  #/     -u <url> | --url=<url> : root url used in generated RSS
  opts.on( '-o', '--output-dir=val', String ) { |val| config['download_root_path'] = val }
  #/     -o <path> | --output-dir=<path> : directory where files are stored
  opts.on( '-i', '--input=val', String ) { |val| feeds << val }
  #/     -i <url> | --input=<url> : url of youtube feed
  # opts.on( '-g', '--opml=val', String ) { |val| opml = val }
  # #/     -g <filepath> | --opml=<filepath> : path of opml file
  
  opts.on_tail( '-h', '--help' ) { exec "grep '^  #/' < '#{__FILE__}'|cut -c6-" }
  #/     -h | --help : this
  opts.parse!
end

feeds.each do |feed|
  convert_feed( feed, config )
end

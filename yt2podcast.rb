#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'fileutils'
require 'open-uri'
require 'optparse'
require 'rexml/document'
require 'rss'

require 'youtube-dl.rb'
require 'taglib'

CONFIG = { root_url: 'http://yt2podcast.le-moine.org',
           download_root_path: './feeds',
           generate_feed: false }

def youtubedl( url, output_file, downloaded_file )
  YoutubeDL.get( url,
                 output: output_file,
                 extract_audio: true,
                 audio_format: 'vorbis',
                 audio_quality: 0 ) unless File.exist? downloaded_file
rescue
  STDERR.puts "Couldn't retrieve video #{url}"
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

  feed_dir = "#{config[ :download_root_path ]}/#{name.tr( ' ', '_' )}"
  dl_dir = "#{feed_dir}"
  FileUtils.mkdir_p( dl_dir ) unless Dir.exist?( dl_dir )

  feed.entries
      .each do |entry|
    video_id = entry.link.href.gsub( 'http://www.youtube.com/watch?v=', '' )
    output_file = "#{dl_dir}/#{video_id}.tmp"
    downloaded_file = "#{dl_dir}/#{video_id}.ogg"
    STDOUT.puts "  🠖 #{video_id}"

    youtubedl( entry.link.href, output_file, downloaded_file )

    if File.exist?( downloaded_file )
      tag( entry, downloaded_file )

      entry.link.href = "#{config[ :root_url ]}/#{name}/#{video_id}.ogg" if CONFIG[ :generate_feed ]
    end
  end

  return unless CONFIG[ :generate_feed ]
  feed.updated = Time.now

  File.open( "#{feed_dir}/feed.xml", 'w' ) do |feed_file|
    feed_file.write( feed.to_atom( 'feed' ).to_s )
  end
end

def parse_opml( opml_node, parent_names=[] )
  feeds = []
  opml_node.elements.each('outline') do |el|
    feeds << parse_opml( el, parent_names + [ el.attributes['text'] ] ) if el.elements.size != 0

    feeds << el.attributes['xmlUrl'] if el.attributes['xmlUrl']
  end

  feeds.flatten
end

feeds = []
ARGV.options do |opts|
  #/ Usage: <progname> [options]...
  opts.on( '-i', '--input=val', String ) { |val| feeds << val }
  #/     -i <url> | --input=<url> : url of youtube feed
  opts.on( '-g', '--opml=val', String ) { |val|
    feeds.concat( parse_opml( REXML::Document.new( File.read( val ) ).elements['opml/body'] ) )
    feeds.flatten
  }
  #/     -g <filepath> | --opml=<filepath> : path of opml file
  opts.on( '-o', '--output-dir=val', String ) { |val| CONFIG[ :download_root_path ] = val }
  #/     -o <path> | --output-dir=<path> : directory where files are stored
  opts.on( '-f', '--feed' ) { CONFIG[ :generate_feed ] = true }
  #/     -f | --feed : enable generation of RSS feed (default: false)
  opts.on( '-u', '--url=val', String ) { |val| CONFIG[ :root_url ] = val }
  #/     -u <url> | --url=<url> : root url used in generated RSS

  opts.on_tail( '-h', '--help' ) { exec "grep '^  #/' < '#{__FILE__}'|cut -c6-" }
  #/     -h | --help : this
  opts.parse!
end

feeds.each do |feed|
  convert_feed( feed, CONFIG )
end

# -*- coding: utf-8 -*-

require 'fileutils'
require 'json'
require 'open-uri'
require 'rss'

require 'youtube-dl.rb'
require 'taglib'

OPTIONS = JSON.parse( File.read( './yt2podcast.json' ) ) if File.exist?( './yt2podcast.json' )
OPTIONS = JSON.parse( File.read( '/etc/yt2podcast.json' ) ) if OPTIONS.nil? && File.exist?( '/etc/yt2podcast.json' )
exit if OPTIONS.nil?

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

def convert_feed( url )
  feed = RSS::Parser.parse( open( url ), false )
  
  name = feed.author.name.content
  STDOUT.puts name
  
  feed_dir = "#{OPTIONS[ 'download_root_path' ]}/#{name.tr( ' ', '_' )}"
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
      
      entry.link.href = "#{OPTIONS['root_url']}/#{name}/medias/#{video_id}.ogg"
    end
  end
  
  feed.updated = Time.now
  
  File.open( "#{feed_dir}/feed.xml", 'w' ) do |feed_file| 
    feed_file.write( feed.to_atom( 'feed' ).to_s )
  end
end

ARGV.each do |feed_url|
  convert_feed( feed_url )
end

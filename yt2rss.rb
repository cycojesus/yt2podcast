# -*- coding: utf-8 -*-

require 'fileutils'
require 'json'
require 'open-uri'
require 'rss'

require 'youtube-dl.rb'
require 'taglib'

configuration  = JSON.parse( File.read( './yt2rss.json' ) ) if File.exist?( './yt2rss.json' )
configuration  = JSON.parse( File.read( '/etc/yt2rss.json' ) ) if configuration.nil? && File.exist?( '/etc/yt2rss.json' )
exit if configuration.nil?

def youtubedl( url, output_file, mp3_file )
  YoutubeDL.get( url,
                 output: output_file,
                 extract_audio: true,
                 audio_format: 'mp3',
                 audio_quality: 0 ) unless File.exist? mp3_file
end

def tag( entry, filename )
  TagLib::FileRef.open( filename ) do |file|
    tag = file.tag
    
    tag.artist = entry.author.name.content
    tag.title = entry.title.content
    
    file.save
  end
end

ARGV.each do |user|
  p user
  feed_dir = "#{configuration[ 'download_root_path' ]}/#{user}"
  dl_dir = "#{feed_dir}/medias"
  FileUtils.mkdir_p( dl_dir ) unless Dir.exist?( dl_dir )
  
  user_feed = RSS::Parser.parse( open( "https://www.youtube.com/feeds/videos.xml?user=#{user}" ), false )
  user_feed.entries
           .each do |entry| 
    video_id = entry.link.href.gsub( 'http://www.youtube.com/watch?v=', '' )
    output_file = "#{dl_dir}/#{video_id}.tmp"
    mp3_file = "#{dl_dir}/#{video_id}.mp3"
    p video_id
      
    youtubedl( entry.link.href, output_file, mp3_file )
    
    tag( entry, mp3_file )
    
    entry.link.href = "#{configuration['root_url']}/#{user}/medias/#{video_id}.mp3"
  end
  
  user_feed.updated = Time.now

  File.open( "#{feed_dir}/feed.xml", 'w' ) do |feed_file| 
    feed_file.write( user_feed.to_atom( 'feed' ).to_s )
  end
end

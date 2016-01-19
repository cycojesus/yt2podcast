# -*- coding: utf-8 -*-

require 'json'
require 'open-uri'
require 'rss'

require 'bundler'
Bundler.require( :default ) # require tout les gems définis dans Gemfile

configuration  = JSON.parse( File.read( './yt2rss.json' ) ) if File.exist?( './yt2rss.json' )
configuration  = JSON.parse( File.read( '/etc/yt2rss.json' ) ) if configuration.nil? && File.exist?( '/etc/yt2rss.json' )
exit if configuration.nil?

ARGV.each do |user|
  p user
  feed_dir = "#{configuration[ 'download_root_path' ]}/#{user}"
  dl_dir = "#{feed_dir}/medias"
  FileUtils.mkdir_p( dl_dir ) unless Dir.exist?( dl_dir )
  
  File.open( "#{feed_dir}/feed.xml", 'w' ) do |feed_file| 
    feed_file.write( RSS::Maker.make( 'atom' ) do |new_rss| 
                       open( "https://www.youtube.com/feeds/videos.xml?user=#{user}" ) do |rss| 
                         yt_rss = RSS::Parser.parse( rss, false )
                         
                         new_rss.channel.author = yt_rss.author.name.content
                         new_rss.channel.link = yt_rss.author.uri.content
                         new_rss.channel.updated = DateTime.now
                         new_rss.channel.about = new_rss.channel.link
                         new_rss.channel.title = yt_rss.title.content
                         new_rss.channel.id = yt_rss.id.content
                         
                         yt_rss.entries
                               .each do |entry| 
                           video_id = entry.link.href.gsub( 'http://www.youtube.com/watch?v=', '' )
                           output_file = "#{dl_dir}/#{video_id}.#{configuration['file_ext']}"
                           p video_id
                           
                           YoutubeDL.get( entry.link.href,
                                          output: output_file,
                                          extract_audio: true,
                                          audio_format: 'mp3',
                                          audio_quality: 0 ) unless File.exist? output_file
                           
                           new_rss.items.new_item do |item|
                             item.link = "#{configuration['root_url']}/#{user}/medias/#{video_id}.#{configuration['file_ext']}"
                             item.title = entry.title
                             item.updated = entry.updated
                           end
                         end
                       end
                     end )
  end
end

# -*- coding: utf-8 -*-

require 'json'
require 'open-uri'
require 'rss'

require 'bundler'
Bundler.require( :default ) # require tout les gems définis dans Gemfile

configuration  = JSON.parse( File.read( '/etc/yt2rss.json' ) ) if File.exist?( '/etc/yt2rss.json' )
configuration  = JSON.parse( File.read( './yt2rss.json' ) ) if configuration.nil? && File.exist?( './yt2rss.json' )

exit if configuration.nil?

ARGV.each do |user|
  p user
  dl_dir = "#{configuration[ 'download_root_path' ]}/#{user}/"
  FileUtils.mkdir_p( dl_dir ) unless Dir.exist?( dl_dir )
  
  open( "https://www.youtube.com/feeds/videos.xml?user=#{user}" ) do |rss| 
    RSS::Parser
      .parse( rss, false )
      .entries
      .each do |entry| 
      video_id = entry.link.href.gsub 'http://www.youtube.com/watch?v=', ''
      p video_id
      
      YoutubeDL.get entry.link.href,
                    output: "#{dl_dir}/#{video_id}.#{configuration['file_ext']}",
                    extract_audio: true,
                    audio_format: 'mp3',
                    audio_quality: 0
    end
  end
end

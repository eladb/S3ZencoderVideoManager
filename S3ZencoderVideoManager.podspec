Pod::Spec.new do |s|
  s.name             = "S3ZencoderVideoManager"
  s.version          = "0.1.0"
  s.summary          = "A video uploader to S3 and Zencoder encoding queue. One file downloader with cache"
  s.homepage         = "https://github.com/sugarso/S3ZencoderVideoManager"
  s.license          = 'MIT'
  s.author           = { "Genady Okrain" => "genady@okrain.com" }
  s.source           = { :git => "https://github.com/sugarso/S3ZencoderVideoManager.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/genadyo'
  s.requires_arc = true
  s.source_files = 'Classes'
  s.resources = 'Resources'
  s.platform = :ios
  s.ios.deployment_target = "7.0"
  s.public_header_files = "Classes/*.h"
  s.dependency 'Parse-iOS-SDK'
  s.dependency 'CLBlockObservation'
  s.dependency 'AWSiOSSDK/Runtime'
  s.dependency 'AWSiOSSDK/S3'
end

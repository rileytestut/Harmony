Pod::Spec.new do |spec|
  spec.name         = "Harmony"
  spec.version      = "0.1"
  spec.summary      = "iOS Syncing Framework"
  spec.description  = "iOS framework that automatically syncs Core Data databases across different backends."
  spec.homepage     = "https://github.com/rileytestut/Harmony"
  spec.platform     = :ios, "12.0"
  spec.source       = { :git => "https://github.com/rileytestut/Harmony.git" }

  spec.author             = { "Riley Testut" => "riley@rileytestut.com" }
  spec.social_media_url   = "https://twitter.com/rileytestut"
  
  spec.source_files  = "Harmony/**/*.{h,m,swift}"
  spec.public_header_files = "Harmony/Harmony.h"
  spec.header_mappings_dir = ""
  spec.resources = "Harmony/**/*.xcdatamodeld"
  
  spec.dependency 'Roxas'
  
  spec.subspec 'Harmony-Dropbox' do |dropbox|
    dropbox.source_files  = "Backends/Dropbox/Harmony-Dropbox/**/*.swift"
    dropbox.dependency 'SwiftyDropbox', '~> 5.0.0'
  end
  
  spec.subspec 'Harmony-Drive' do |drive|
    drive.source_files  = "Backends/Drive/Harmony-Drive/**/*.swift"
    drive.dependency 'GoogleAPIClientForREST/Drive', '~> 1.3.0'
    drive.dependency 'GoogleSignIn', '~> 4.4.0'
  end
  
end

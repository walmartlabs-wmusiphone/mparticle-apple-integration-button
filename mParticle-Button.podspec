Pod::Spec.new do |s|
    s.name             = "mParticle-Button"
    s.version          = "7.16.2"
    s.summary          = "Button integration for mParticle"

    s.description      = <<-DESC
                       This is the Button integration for mParticle.
                       DESC

    s.homepage         = "https://www.mparticle.com"
    s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
    s.author           = { "mParticle" => "support@mparticle.com" }
    s.source           = { :git => "https://github.com/mparticle-integrations/mparticle-apple-integration-button.git", :tag => s.version.to_s }
    s.social_media_url = "https://twitter.com/mparticle"

    s.ios.deployment_target = "9.0"
    s.ios.source_files      = 'mParticle-Button/*.{h,m,mm}'
    s.ios.dependency 'mParticle-Apple-SDK/mParticle', '~> 7.0'
    s.ios.dependency 'ButtonMerchant', '~> 1.0'
    s.swift_version = '4.1'
end

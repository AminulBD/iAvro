# Vendored copy of RegexKitLite 4.0 (r69). The upstream podspec fetches from a
# SourceForge SVN repository, which requires `svn` and is not available on CI.
Pod::Spec.new do |s|
  s.name         = 'RegexKitLite'
  s.version      = '4.0'
  s.license      = { :type => 'BSD', :file => 'LICENSE.txt' }
  s.summary      = 'Lightweight Objective-C Regular Expressions using the ICU Library.'
  s.homepage     = 'http://regexkit.sourceforge.net/RegexKitLite/'
  s.authors      = { 'John Engelhart' => 'regexkitlite@gmail.com' }
  s.source       = { :git => 'https://github.com/AminulBD/iAvro.git' }
  s.osx.deployment_target = '12.0'
  s.source_files = 'RegexKitLite.{h,m}'
  s.libraries    = 'icucore'
  s.requires_arc = false
end

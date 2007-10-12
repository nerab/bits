require 'rubygems'

spec = Gem::Specification.new do |s|

    s.name = 'bits'
    s.version = "0.1.2"
    # s.platform = Gem::Platform::Win32
    s.platform = "mswin32"
    s.summary = "A ruby interface for the Background Intelligent Transfer Service (BITS)"
    s.requirements << 'Background Intelligent Transfer Service (BITS) für Windows (KB842773)'
    s.requirements << 'bitsadmin tool, available at http://www.microsoft.com/downloads/details.aspx?amp;displaylang=en&familyid=49AE8576-9BB9-4126-9761-BA8011FABF38&displaylang=en'
    s.files = Dir.glob("lib/**/*").delete_if {|item| item.include?(".svn")}
    s.require_path = 'lib'
    # s.autorequire = 'bits/bits'
    s.author = "Nicolas E. Rabenau"
    s.email = "nerab@gmx.at"
    s.rubyforge_project = "bits"
    s.homepage = "http://bits.rubyforge.org"
    s.has_rdoc = true
    s.test_files = Dir.glob('test/test_*.rb')
end

if $0==__FILE__
    Gem.manage_gems
    Gem::Builder.new(spec).build
end

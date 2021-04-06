require File.expand_path("../lib/capistrano/scm/rsync/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name = "capistrano-rsync-bladrak"
  gem.version = Capistrano::SCM::Rsync::VERSION
  gem.homepage = "https://github.com/Bladrak/capistrano-rsync"
  gem.summary = <<-end.strip.gsub(/\s*\n\s*/, " ")
    Increase deployment performance through rsync
    Capistrano v3 ready!
    This is a maintained fork of capistrano-rsync
  end

  gem.description = <<-end.strip.gsub(/\s*?\n(\n?)\s*/, " \\1\\1")
    This is a rsync 'scm' for Capistrano v3, drastically improving deployment
    performance, and avoiding you to install git on production servers.

    This was originally a fork of capistrano-rsync.
  end

  gem.author = "Hugo Briand, Andri Möll"
  gem.email = "h.briand@gmail.com, andri@dot.ee"
  gem.license = "LAGPL"

  gem.files = `git ls-files`.split($/)
  gem.executables = gem.files.grep(/^bin\//).map(&File.method(:basename))
  gem.test_files = gem.files.grep(/^spec\//)
  gem.require_paths = ["lib"]

  gem.add_dependency "capistrano", ">= 3.0.0.pre14", "< 4"
end

# frozen_string_literal: true

require 'open3'
require 'tempfile'

# This installer accepts the known Debian ImageMagick 6/7 policy layout. It is
# deliberately not a general XML editor: unexpected layouts fail the build.
module ImageMagickDocumentPolicy
  BEGIN_MARKER = '<!-- BEGIN Trove document policy -->'
  END_MARKER = '<!-- END Trove document policy -->'
  FRAGMENT_PATH = File.expand_path('../config/imagemagick/document-policy.xml', __dir__)

  def self.without_comments(xml)
    xml.gsub(/<!--.*?-->/m) { |comment| ' ' * comment.length }
  end

  def self.policy_body(xml)
    structure = without_comments(xml)
    structure.sub!(/\A\s*<\?xml\b.*?\?>/m, '')
    structure.sub!(/\A\s*<!DOCTYPE\s+policymap(?:\s*\[.*?\])?\s*>/m, '')
    root = structure.match(%r{\A\s*<policymap>(.*?)</policymap>\s*\z}m)
    unless root && root[1].gsub(%r{<policy\b[^<>]*/>}m, '').strip.empty?
      raise 'Unrecognized policy XML: expected one policymap containing only policy elements'
    end

    root[1].strip
  end

  def self.remove_managed_block(xml)
    counts = [BEGIN_MARKER, END_MARKER].map { |marker| xml.scan(marker).length }
    raise 'Incomplete or duplicate Trove policy markers' unless [[0, 0], [1, 1]].include?(counts)
    return xml if counts == [0, 0]

    existing = xml.match(/^[ \t]*#{Regexp.escape(BEGIN_MARKER)}\r?\n.*?^[ \t]*#{Regexp.escape(END_MARKER)}\r?\n/m)
    structure = without_comments(xml)
    unless existing && existing.begin(0) > structure.index('<policymap>') &&
           existing.end(0) <= structure.index('</policymap>')
      raise 'Trove policy markers are outside the policymap or out of order'
    end

    xml.sub(existing[0], '')
  end

  def self.updated_policy(original, fragment)
    policy_body(original)
    body = policy_body(fragment)
    raise 'Document policy fragment is empty' if body.empty?

    updated = remove_managed_block(original).dup
    policy_body(updated)
    block = "  #{BEGIN_MARKER}\n#{body.lines.map { |line| "  #{line.strip}\n" }.join}  #{END_MARKER}\n"
    updated.insert(without_comments(updated).index('</policymap>'), block)
    policy_body(updated)
    updated
  end

  def self.install!(path, fragment_path = FRAGMENT_PATH)
    raise "Refusing symlink policy: #{path}" if File.symlink?(path)

    original = File.read(path)
    updated = updated_policy(original, File.read(fragment_path))
    return if updated == original

    Tempfile.create(['trove-policy-', '.xml'], File.dirname(path)) do |file|
      file.write(updated)
      file.flush
      file.chmod(File.stat(path).mode & 0o777)
      File.rename(file.path, path)
    end
    path
  end

  def self.output(command, *arguments)
    stdout, stderr, status = Open3.capture3(command, *arguments)
    raise "#{File.basename(command)} #{arguments.join(' ')} failed: #{stderr.strip}" unless status.success?

    stdout
  end

  def self.commands
    commands = %w[magick identify].filter_map do |name|
      ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).map { |directory| File.join(directory, name) }
         .find { |path| File.file?(path) && File.executable?(path) }
    end
    raise 'ImageMagick magick/identify command not found' if commands.empty?

    commands
  end

  def self.policy_path(command)
    version = output(command, '-version').match(/Version: ImageMagick (\d+)\.(\d+)\.(\d+)(?:-(\d+))?/)
    parts = version&.captures&.map(&:to_i)
    minimum = { 6 => [6, 9, 4, 6], 7 => [7, 0, 1, 8] }[parts&.first]
    raise "Unsupported ImageMagick version from #{command}" unless minimum && (parts <=> minimum) >= 0

    expected = "/etc/ImageMagick-#{parts.first}/policy.xml"
    configured = output(command, '-list', 'configure').lines.filter_map { |line| line[/\ACONFIGURE_PATH\s+(\S+)/, 1] }
    loaded = output(command, '-list', 'policy').lines.filter_map { |line| line[/\APath:\s+(.+?)\s*\z/, 1] } - ['[built-in]']
    unless configured.map { |path| path.delete_suffix('/') }.uniq == [File.dirname(expected)] && loaded.uniq == [expected]
      raise "Unrecognized ImageMagick configuration for #{command}; expected only #{expected}"
    end

    expected
  end

  def self.run!
    if %w[MAGICK_CONFIGURE_PATH MAGICK_HOME].any? { |name| !ENV[name].to_s.empty? }
      raise 'Remove ImageMagick configuration overrides before installing the default policy'
    end

    commands = self.commands
    paths = commands.map { |command| policy_path(command) }
    paths.uniq.each do |path|
      puts "#{install!(path) ? 'Installed' : 'Already installed'} Trove document policy: #{path}"
    end
    commands.each { |command| output(command, '-list', 'policy') }
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    ImageMagickDocumentPolicy.run!
  rescue StandardError => e
    abort "ImageMagick policy installation failed: #{e.message}"
  end
end

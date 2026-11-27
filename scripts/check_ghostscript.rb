# frozen_string_literal: true

# Read-only final-image check. No Rails boot, Ghostscript execution, or package changes.
require 'open3'

module GhostscriptCheck
  module Files
    SEARCH_ROOTS = %w[/usr/local /opt /rails /usr/bin /bin /usr/lib /lib /usr/lib64 /lib64].freeze

    def artifact_name?(name)
      %w[gs libgs].include?(name) || name.match?(/\Alibgs(?:\.so(?:\..+)?|\.a|(?:\.\d+)*\.dylib)\z/)
    end

    def path_artifacts
      search_path = ENV.fetch('PATH', '').split(File::PATH_SEPARATOR, -1)
      search_path = ['.'] if search_path.empty?
      search_path.filter_map do |directory|
        path = File.expand_path('gs', directory.empty? ? '.' : directory)
        path if File.exist?(path) || File.symlink?(path)
      end
    end

    def inspected_directory?(path, roots)
      roots.any? { |root| path == root || path.start_with?("#{root}/") }
    end

    # Bound directory traversal to these roots, including their canonical /lib aliases.
    # Artifact symlinks are still returned for verification of their resolved files.
    def artifact_paths
      paths = path_artifacts
      roots = SEARCH_ROOTS.filter_map { |root| File.realpath(root) if File.exist?(root) || File.symlink?(root) }
      pending = roots.uniq
      visited = {}
      until pending.empty?
        path = pending.pop
        if File.directory?(path)
          resolved = File.realpath(path)
          unless inspected_directory?(resolved, roots)
            puts "Skipped directory outside Ghostscript scan roots: #{path} -> #{resolved}"
            next
          end
          next if visited[resolved]

          visited[resolved] = true
          pending.concat(Dir.children(path).map { |name| File.join(path, name) })
        elsif artifact_name?(File.basename(path))
          paths << path
        end
      end
      paths.uniq.sort
    end
  end

  extend Files

  class Failure < StandardError; end

  # https://security-tracker.debian.org/tracker/CVE-2026-125396
  # Compare Debian source revisions; an older upstream version can contain the fix.
  FIXED_SOURCE_VERSIONS = {
    'bookworm' => '10.0.0~dfsg-11+deb12u9',
    'trixie' => '10.05.1~dfsg-1+deb13u2'
  }.freeze
  DPKG_QUERY = '/usr/bin/dpkg-query'
  DPKG = '/usr/bin/dpkg'

  module_function

  def command!(*arguments)
    output, error, status = Open3.capture3(*arguments)
    raise Failure, "#{arguments.first} failed: #{error.strip}" unless status.success?

    output
  end

  def package_inventory
    format = "${db:Status-Status}\t${binary:Package}\t${Version}\t${source:Package}\t${source:Version}\n"
    rows = command!(DPKG_QUERY, '-W', '-f', format).lines
    raise Failure, 'Package inventory is empty' if rows.empty?

    rows.to_h do |line|
      state, name, version, source, source_version, extra = line.chomp.split("\t", -1)
      if extra || [state, name].any? { |value| value.nil? || value.empty? } ||
         (state == 'installed' && [version, source, source_version].any? { |value| value.nil? || value.empty? })
        raise Failure, 'Package inventory is incomplete'
      end

      [name, { state: state, version: version, source: source, source_version: source_version }]
    end
  end

  def distribution
    File.read('/etc/os-release').scan(/^(ID|VERSION_CODENAME)=["']?([a-z0-9-]+)["']?$/).to_h
  end

  def check_packages(packages, release)
    ghostscript = packages.select { |_name, package| package[:source] == 'ghostscript' }
    ghostscript.reject! { |_name, package| %w[not-installed config-files].include?(package[:state]) }
    return if ghostscript.empty?

    codename = release['VERSION_CODENAME']
    minimum = FIXED_SOURCE_VERSIONS[codename] if release['ID'] == 'debian'
    raise Failure, 'Unknown distribution fix for installed Ghostscript (CVE-2026-125396)' unless minimum

    ghostscript.each do |name, package|
      raise Failure, "#{name} is not fully installed (#{package[:state]})" unless package[:state] == 'installed'

      puts "#{name}: binary=#{package[:version]} source=ghostscript #{package[:source_version]} suite=#{codename}"
      _output, error, status = Open3.capture3(DPKG, '--compare-versions', package[:source_version], 'ge', minimum)
      raise Failure, "Version comparison failed: #{error.strip}" unless [0, 1].include?(status.exitstatus)
      raise Failure, "#{name} is below the fixed #{codename} source version #{minimum}" unless status.success?
    end
  end

  def check_artifacts(paths, packages)
    paths.each do |path|
      resolved = File.realpath(path)
      output, _error, status = Open3.capture3(DPKG_QUERY, '-S', resolved)
      owners = output.lines.filter_map do |line|
        name, owned_path = line.chomp.split(': ', 2)
        name if owned_path == resolved
      end
      verified = owners.all? do |name|
        package = packages[name]
        package && package[:state] == 'installed' && package[:source] == 'ghostscript'
      end
      unless status.success? && !owners.empty? && verified
        raise Failure, "Unmanaged or unverified Ghostscript artifact requires review: #{path} -> #{resolved}"
      end

      puts "Ghostscript artifact: #{path} -> #{resolved} (#{owners.join(', ')})"
    end
  end

  def run
    packages = package_inventory
    check_packages(packages, distribution)
    check_artifacts(artifact_paths, packages)
    present = packages.values.any? { |package| package[:source] == 'ghostscript' && package[:state] == 'installed' }
    result = present ? 'installed packages meet verified Debian fixes' : 'no gs/libgs found in inspected locations'
    puts "Ghostscript check passed: #{result}."
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    GhostscriptCheck.run
  rescue StandardError => e
    warn "Ghostscript check failed: #{e.message}"
    exit 1
  end
end

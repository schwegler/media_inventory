# frozen_string_literal: true

# Run directly with ruby, without spec_helper or Rails/database initialization.
require 'fileutils'
require 'stringio'
require 'tmpdir'
require_relative '../../scripts/check_ghostscript'

def assert_check(condition, message)
  raise message unless condition
end

def must_reject(label, error: GhostscriptCheck::Failure)
  yield
  raise "Expected rejection: #{label}"
rescue error
  true
end

def with_scan_root(root)
  original_roots = GhostscriptCheck::Files::SEARCH_ROOTS
  original_path = ENV.fetch('PATH', nil)
  GhostscriptCheck::Files.send(:remove_const, :SEARCH_ROOTS)
  GhostscriptCheck::Files.const_set(:SEARCH_ROOTS, [root])
  ENV['PATH'] = File.join(root, 'bin')
  yield
ensure
  ENV['PATH'] = original_path
  GhostscriptCheck::Files.send(:remove_const, :SEARCH_ROOTS)
  GhostscriptCheck::Files.const_set(:SEARCH_ROOTS, original_roots)
end

package = lambda do |name, version, state = 'installed'|
  { name => { state: state, version: version, source: 'ghostscript', source_version: version } }
end
release = ->(suite) { { 'ID' => 'debian', 'VERSION_CODENAME' => suite } }
original_stdout = $stdout
evidence = StringIO.new

begin
  $stdout = evidence
  GhostscriptCheck.check_packages({}, release.call('bookworm'))
  GhostscriptCheck.check_artifacts([], {})
  [
    ['bookworm', '10.0.0~dfsg-11+deb12u8', '10.0.0~dfsg-11+deb12u9', '10.0.0~dfsg-11+deb12u10'],
    ['trixie', '10.05.1~dfsg-1+deb13u1', '10.05.1~dfsg-1+deb13u2', '10.05.1~dfsg-1+deb13u3']
  ].each do |suite, vulnerable, fixed, newer|
    %w[libgs10:amd64 ghostscript-common].each do |name|
      must_reject("#{suite}: vulnerable library/data package without CLI") do
        GhostscriptCheck.check_packages(package.call(name, vulnerable), release.call(suite))
      end
      [fixed, newer].each { |version| GhostscriptCheck.check_packages(package.call(name, version), release.call(suite)) }
    end
  end
  must_reject('unknown suite despite newer upstream version') do
    GhostscriptCheck.check_packages(package.call('ghostscript', '10.08.0'), release.call('forky'))
  end
  must_reject('non-Debian distribution') do
    GhostscriptCheck.check_packages(package.call('ghostscript', '10.08.0'),
                                    { 'ID' => 'ubuntu', 'VERSION_CODENAME' => 'trixie' })
  end
  must_reject('partly installed package') do
    GhostscriptCheck.check_packages(package.call('ghostscript', '10.0.0~dfsg-11+deb12u9', 'unpacked'),
                                    release.call('bookworm'))
  end
  %w[gs libgs libgs.so libgs.so.10 libgs.so.10.00 libgs.a].each do |name|
    assert_check(GhostscriptCheck.artifact_name?(name), "Missed Ghostscript filename #{name}")
  end
  %w[libgsf-1.so libgsf-1.so.114 libgsl.so libgssapi_krb5.so].each do |name|
    assert_check(!GhostscriptCheck.artifact_name?(name), "Misidentified #{name} as Ghostscript")
  end

  Dir.mktmpdir('trove-gs-check-test-') do |directory|
    root = File.join(directory, 'app')
    bundle = File.join(root, 'vendor', 'bundle')
    private_outside = File.join(directory, 'outside-private')
    private_inside = File.join(root, 'inside-private')
    FileUtils.mkdir_p([bundle, private_outside, File.join(root, 'bin')])
    library = File.join(bundle, 'libgs.so.10.00')
    executable = File.join(root, 'bin', 'gs')
    unrelated = File.join(bundle, 'libgsf-1.so.114')
    [library, executable, unrelated].each { |path| File.write(path, 'Benign inventory fixture, never execute.') }
    external_file = File.join(directory, 'libgs.so.10')
    File.write(external_file, 'Unmanaged library fixture, never load.')
    file_link = File.join(root, 'libgs.so.10')
    File.symlink(external_file, file_link)
    File.symlink(private_outside, File.join(root, 'private-directory-link'))
    File.symlink(bundle, File.join(root, 'bundle-link'))
    File.symlink(root, File.join(root, 'cycle'))
    File.chmod(0o000, private_outside)
    begin
      with_scan_root(root) do
        paths = GhostscriptCheck.artifact_paths
        resolved = paths.map { |path| File.realpath(path) }
        assert_check(resolved.include?(library), 'Bundled library was missed')
        assert_check(resolved.include?(executable), 'PATH executable was missed')
        assert_check(!resolved.include?(unrelated), 'libgsf was mistaken for Ghostscript')
        assert_check(paths.include?(file_link), 'Artifact file symlink outside roots was missed')
        assert_check(evidence.string.include?('Skipped directory outside Ghostscript scan roots:'),
                     'External directory symlink was not reported')
        [library, executable, file_link].each do |path|
          must_reject("unmanaged artifact #{File.basename(path)}") { GhostscriptCheck.check_artifacts([path], {}) }
        end
        unless Process.uid.zero?
          Dir.mkdir(private_inside)
          File.chmod(0o000, private_inside)
          must_reject('unreadable directory inside roots', error: Errno::EACCES) { GhostscriptCheck.artifact_paths }
        end
      end
    ensure
      File.chmod(0o700, private_outside)
      File.chmod(0o700, private_inside) if File.directory?(private_inside)
    end
  end
ensure
  $stdout = original_stdout
end

warn 'Permission-denial regression skipped because this test is running as root.' if Process.uid.zero?
puts 'Ghostscript gate checks passed: Debian versions, library/data-only packages, unmanaged files, and bounded discovery.'

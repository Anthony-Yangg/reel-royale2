#!/usr/bin/env ruby
# Add Swift files to ReelRoyale.xcodeproj.
# Usage: ruby add_to_xcodeproj.rb <relative/path/from/repo/root.swift> [<more.swift>...]
# Idempotent — skips files already in the project.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../../../ReelRoyale.xcodeproj', __FILE__)
PROJECT_ROOT = File.expand_path('../../../', __FILE__)
PROJECT_DIR_NAME = 'ReelRoyale' # the source directory under repo root

abort "Usage: #{$0} <file.swift> [...]" if ARGV.empty?

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == 'ReelRoyale' }
abort "Could not find target 'ReelRoyale'" unless target

main_group = project.main_group[PROJECT_DIR_NAME]
abort "Could not find main group '#{PROJECT_DIR_NAME}'" unless main_group

def ensure_group(parent, name)
  existing = parent.groups.find { |g| g.display_name == name || g.name == name || g.path == name }
  return existing if existing
  parent.new_group(name, name)
end

added_count = 0
ARGV.each do |rel|
  abs = File.expand_path(rel, PROJECT_ROOT)
  unless File.exist?(abs)
    warn "Skip (missing on disk): #{rel}"
    next
  end

  # Path under ReelRoyale/ (the source root)
  prefix = "#{PROJECT_DIR_NAME}/"
  unless rel.start_with?(prefix)
    warn "Skip (not under #{prefix}): #{rel}"
    next
  end
  relative_to_source = rel[prefix.length..]

  parts = relative_to_source.split('/')
  filename = parts.pop
  group = main_group
  parts.each { |p| group = ensure_group(group, p) }

  already = group.files.find { |f| f.display_name == filename || f.path == filename }
  if already
    warn "Already in project: #{rel}"
    next
  end

  file_ref = group.new_reference(filename)
  file_ref.last_known_file_type = 'sourcecode.swift'

  target.add_file_references([file_ref])
  added_count += 1
  puts "Added: #{rel}"
end

project.save
puts "Saved. Added #{added_count} file(s)."

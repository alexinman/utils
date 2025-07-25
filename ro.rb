require "mime/types"
require "fileutils"
require "exif"
require "pry"

# moves and reorganizes files from source directory into target directory.
# reorganizes into subdirectories based on creation date.
def reorganize(method_name, source_dir, target_dir, verbose: false, noop: false, flat: false, media_types: nil)
  start_time = Time.now

  options = {verbose:, noop:}
  options[:preserve] = true if method_name == :cp

  puts "Scanning directory for files..."
  moves = generate_moves(source_dir, target_dir, flat:, media_types:)
  puts "Done."

  unless flat
    puts "Creating date directories..."
    moves.map { _2 }.uniq.each { FileUtils.mkdir_p(_1, verbose:, noop:) }
    puts "Done."
  end

  puts "Moving files... "
  move_start_time = Time.now
  moves.each_with_index do |(source_file_path, target_dir_path, file_name), index|
    target_file_path = dedup_file_name(source_file_path, "#{target_dir_path}/#{file_name}")
    next if target_file_path.nil?

    FileUtils.send(method_name, source_file_path, target_file_path, **options)
    print_progress(move_start_time, index + 1, moves.size)
  rescue
    warn "Failed attempting to move #{source_file_path.inspect} to #{target_file_path.inspect}"
    raise
  end
  FileUtils.rm_rf(source_dir, verbose:, noop:) if method_name.to_sym == :mv

  elapsed_time = format_time(Time.now - start_time)
  puts "\rDone. Moved #{moves.size} files. Total elapsed time: #{elapsed_time}"
rescue => e
  puts e.message
  puts e.backtrace.first(5)
end

def generate_moves(source_dir, target_dir, flat: false, media_types: nil)
  puts "Scanning #{source_dir.inspect}..."

  moves = []

  Dir.children(source_dir).sort.each do |file_name|
    next if file_name.start_with?(".") # skip hidden files

    source_file_path = "#{source_dir}/#{file_name}"

    if File.directory?(source_file_path)
      moves += generate_moves(source_file_path, target_dir, flat:, media_types:)
      next
    end

    next unless matches_media_types?(media_types, source_file_path)

    date_path = get_date(source_file_path).strftime("%Y/%m/%d") unless flat

    target_file_dir = [target_dir, date_path].compact.join("/")

    target_file_name = fix_extension(source_file_path, file_name)

    moves << [source_file_path, target_file_dir, target_file_name]
  end

  moves
end

def fix_extension(source_file_path, file_name)
  return file_name if file_name.end_with?(".CR3")

  mime_type = `file --mime-type -b #{source_file_path.inspect}`.chomp
  valid_extensions = MIME::Types[mime_type].first&.extensions
  return file_name if valid_extensions.nil?

  _, current_extension = file_name.match(/\.(\w+)$/).to_a
  return file_name if valid_extensions.include?(current_extension)

  file_name.sub(/#{current_extension}$/, valid_extensions.first)
end

def matches_media_types?(media_types, file_path)
  return true if media_types.nil?
  return true if media_types.empty?
  return true if media_types.include?(MIME::Types.type_for(file_path).first&.media_type)
  media_types.map(&:downcase).include?(file_path.split('.').last.downcase)
end

def get_date(file_path)
  File.open(file_path) do |file|
    data = Exif::Data.new(file)
    next File.birthtime(file_path) if data.date_time_original.nil?

    _, year, month, day, hour, min, sec = data.date_time_original.match(/(\d\d\d\d):(\d\d):(\d\d) (\d\d):(\d\d):(\d\d)/).to_a
    Time.new(year, month, day, hour, min, sec)
  end
rescue
  File.birthtime(file_path)
end

def dedup_file_name(source_file_path, base_file_path, depth = 1)
  ext = File.extname(base_file_path)
  full_file_path = depth > 1 ? base_file_path.gsub(ext, "-#{depth}#{ext}") : base_file_path

  if File.exist?(full_file_path)
    unless File.identical?(source_file_path, full_file_path)
      dedup_file_name(source_file_path, base_file_path, depth+1)
    end
  else
    full_file_path
  end
end

def print_progress(start_time, completed_count, total_count)
  elapsed_time = Time.now - start_time
  average_time = elapsed_time / completed_count
  estimated_total_time = average_time * total_count
  estimated_time_left = estimated_total_time - elapsed_time
  formatted_time = format_time(estimated_time_left)
  puts "(#{completed_count}/#{total_count}) ETA: #{formatted_time}"
end

def format_time(total_seconds)
  seconds = "#{total_seconds.to_i % 60}".rjust(2, '0')
  total_minutes = total_seconds.to_i / 60
  minutes = "#{total_minutes % 60}".rjust(2, '0')
  hours = "#{total_minutes / 60}".rjust(2, '0')
  "#{hours}:#{minutes}:#{seconds}"
end

method_name, source_dir, target_dir, *rest = ARGV
unless method_name.to_sym == :mv || method_name.to_sym == :cp
  warn "Unsupport move type: #{method_name.inspect}"
  exit 1
end

unless File.directory?(source_dir.to_s)
  warn "Source #{source_dir.inspect} is not a directory." 
  exit 1
end

unless File.directory?(target_dir.to_s)
  warn "Target #{target_dir.inspect} is not a directory."
  exit 1
end

verbose = !!rest.delete("--verbose")
noop = !!rest.delete("--noop")
flat = !!rest.delete("--flat")
media_types = rest + ['image', 'video', 'cr3']

reorganize(method_name, source_dir, target_dir, verbose:, noop:, flat:, media_types:)
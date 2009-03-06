require 'rubygems'
require 'colorize'

module GitUI
	class Action
		attr_accessor :key, :desc, :block
		def initialize(k, d, &b)
			@key = k
			@desc = d
			@block = b
		end
	end

	def act *a, &b
		Action.new(*a, &b)
	end

	def compose *lambdas
		lambda { |*args|
			lambdas.reverse.inject(args) { |acc, f| f.call *acc }
		}
	end

	def pager
		@pager ||= %w(GIT_UI_PAGER GIT_PAGER PAGER
					 ).map { |e| ENV[e] }.compact.first || 'less'
	end

	def editor
		@editor ||= %w(GIT_UI_EDITOR GIT_EDITOR VISUAL EDITOR
					  ).map { |e| ENV[e] }.compact.first || 'vi'
	end

	def find_dotgit(path = '.')
		path = original_path = File.expand_path(path)
		loop {
			return path if File.directory?(File.join(path, '.git'))
			p = File.expand_path File.join(path, '..')
			if p == path
				raise RuntimeError, "#{original_path} does not appear " \
					"to be inside a git repository."
			end
			path = p
		}
	end

	def changes
		IO.popen('git diff --raw', 'r').readlines.grep(/^:/).map { |l|
			src_mode, dst_mode, src_sha1, dst_sha1, status, src_path, dst_path =
				l.sub(/^:/, '').split(/\s+/)
			{ :status => status,
			  :filename => (dst_path || src_path).chomp,
			}
		}
	end

	def untracked_files
		IO.popen('git ls-files -o --exclude-standard', 'r').readlines.map { |f|
			{ :filename => f.chomp }
		}
	end

	def add_untracked
		cs = untracked_files
		color = :yellow

		if cs.empty?
			puts "No new files; try your .gitignore, maybe?".colorize(color)
			return []
		end

		i = 0
		acts = [
			act('y', "Yes, add this file.") { 
				cs[i][:action] = :add; i += 1 },
			act('n', 'No, don\'t add this file.') {
				cs[i][:action] = nil; i += 1 },
			act('v', 'View the file') {
				print File.read(cs[i][:filename]) },
			act('p', "View this file in a pager (#{pager})") {
				system "#{pager} #{cs[i][:filename]}" },
			act('e', "Edit this file using \"#{editor}\"") {
				edit cs[i][:filename] },
			act('d', 'Done, skip to commit step.') { i = cs.size },
			act('a', 'Add all remaining') {
				cs[i..-1].each { |c| c[:action] = :add }
				i = cs.size },
			act('q', 'Quit, skip commit step.') { cs.clear },
			act('j', 'Jump to next file in list') { i += 1 },
			act('k', 'Go back to previous file in list') { 
				i -= 1; i = 0 if i < 0 },
		]

		while i < cs.size
			puts "#{cs[i][:filename]} (#{i + 1}/#{cs.size})"
			decide "Add?", acts, color
		end

		cs
	end

	def decide prompt, acts, color = :default
		keys = acts.map { |act| act.key } << '?'
		prompt = "#{prompt} [#{keys.join('')}]: ".colorize(color)

		act = nil
		loop {
			print prompt
			$stdout.flush
			inp = $stdin.read(1)
			print "\n"
			if inp == '?'
				puts acts.map { |a|
					"  #{a.key}: #{a.desc}"
				}
			elsif a = acts.find { |a| inp == a.key }
				return a.block.call
			else
				puts "No such action:  #{inp}"
			end
		}
	end

	def edit filename
		system editor, filename
	end

	def record *args
		cs = changes
		if cs.empty?
			puts "No changes to record!".colorize(:cyan)
			return []
		end
		i = 0

		acts = [
			act('y', "Yes, commit this change.") { 
				cs[i][:action] = :commit; i += 1 },
			act('n', 'No, don\'t commit this change.') {
				cs[i][:action] = nil; i += 1 },
			act('v', 'View this patch') {
				system "git diff #{cs[i][:filename]}" },
			act('p', "View this patch in a pager (#{pager})") {
				system "git diff #{cs[i][:filename]} | #{pager}" },
			act('e', "Edit this file using \"#{editor}\"") {
				edit cs[i][:filename] },
			act('d', 'Done, skip to commit step.') { i = cs.size },
			act('a', 'Record all remaining') {
				cs[i..-1].each { |c| c[:action] = :record }
				i = cs.size },
			act('q', 'Quit, skip commit step.') { cs.clear },
			act('j', 'Jump to next patch in list') { i += 1 },
			act('k', 'Go back to previous patch in list') { 
				i -= 1; i = 0 if i < 0 },
		]

		while i < cs.size
			puts "#{cs[i][:filename]} #{cs[i][:status]} (#{i + 1}/#{cs.size})"
			decide "Record?", acts, :cyan
		end

		cs
	end

	def commit(*cs)
		fs = cs.select { |c| 
			[:commit, :add].include? c[:action]
		}.map { |c| c[:filename] }
		if fs.empty?
			puts "Nothing to commit.".colorize(:red)
			return
		end
		puts "Committing #{fs.join(', ')}...".colorize(:green)
		system 'git', 'add', *fs
		system 'git', 'commit', *fs
	end

	def determine_cmd args
		stty_cooked = lambda { |*args| system "stty sane"; args }
		stty_raw = lambda { |*args| system "stty -icanon min 1"; args }

		cmd, *args = args

		case cmd
		when /^rec/i
			lambda {
				compose(method(:commit),
						stty_cooked, 
						method(:record), 
						stty_raw)[*args]
			}
		when /^add/i
			lambda {
				compose(method(:commit),
						stty_cooked,
						method(:add_untracked),
						stty_raw)[*args]
			}
		else
			nil
		end
	end

	extend self
end

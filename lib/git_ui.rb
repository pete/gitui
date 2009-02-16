require 'colorize'

module GitUI
	def compose *lambdas
		lambda { |*args|
			lambdas.reverse.inject(args) { |acc, f|
				f.call *acc
			}
		}
	end

	def pager
		@pager ||= ENV['PAGER'] || 'less'
	end

	def changes
		IO.popen('git diff --raw', 'r').readlines.grep(/^:/).map { |l|
			src_mode, dst_mode, src_sha1, dst_sha1, status, src_path, dst_path =
				l.sub(/^:/, '').split(/\s+/)
			{ :status => status,
			  :filename => dst_path || src_path,
			}
		}
	end

	def record *args
		cs = changes
		if cs.empty?
			puts "No changes to record!".colorize(:cyan)
			return []
		end
		i = 0
		while i < cs.size
			puts "#{cs[i][:filename]} #{cs[i][:status]} (#{i + 1}/#{cs.size})"
			print "Record? [ynvpdaqjk]: ".colorize(:cyan)
			$stdout.flush
			inp = $stdin.read(1)
			print "\n"
			case inp
			when 'y'
				cs[i][:action] = :commit
				i += 1
			when 'n'
				cs[i][:action] = nil
				i += 1
			when 'v'
				system "git diff #{cs[i][:filename]}"
			when 'p'
				system "git diff #{cs[i][:filename]} | #{pager}"
			when 'd'
				i = cs.size
			when 'a'
				cs[i..-1].each { |c| c[:action] = :record }
				i = cs.size
			when 'q'
				return []
			when 'j'
				i += 1
			when 'k'
				i -= 1; i = 0 if i < 0
			else
				puts "Invalid option: #{inp.inspect}!"
			end
		end

		cs
	end

	def commit(*cs)
		fs = cs.select { |c| c[:action] == :commit }.map { |c| c[:filename] }
		system "git commit #{fs.join(' ')}"
	end

	def determine_cmd args
		stty_cooked = lambda { |*args| system "stty sane"; args }
		stty_raw = lambda { |*args| system "stty -icanon min 1"; args }

		case args.first
		when /^rec/i
			lambda {
				compose(stty_cooked, 
						method(:commit),
						method(:record), 
						stty_raw)[*args[1..-1]]
			}
		else
			nil
		end
	end

	extend self
end

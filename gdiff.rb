#!/usr/bin/ruby

# Copyright 2018 hidenorly
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'optparse'
require 'shellwords'

class StrUtil
	def self.ensureUtf8(str, replaceChr="_")
		str = str.to_s
		str.encode!("UTF-8", :invalid=>:replace, :undef=>:replace, :replace=>replaceChr) if !str.valid_encoding?
		return str
	end
end


class FileUtil
	def self.ensureDirectory(path)
		paths = path.split("/")

		path = ""
		paths.each do |aPath|
			path += "/"+aPath
			Dir.mkdir(path) if !Dir.exist?(path)
		end
	end
end


class ExecUtil
	def self.execCmd(command, execPath=".", quiet=true)
		if File.directory?(execPath) then
			exec_cmd = command
			exec_cmd += " > /dev/null 2>&1" if quiet && !exec_cmd.include?("> /dev/null")
			system(exec_cmd, :chdir=>execPath)
		end
	end
end


class DiffWithGit
	def initialize(srcPath, dstPath, patchPath, exclude, verbose)
		@srcPath = srcPath
		@dstPath = dstPath
		@patchPath = patchPath
		@excludes = exclude.split("|")
		@excludes = [ exclude.to_s.strip ] if !@excludes.to_a.length
		@verbose = verbose
	end

	DEF_EXEC_DIFF = "git diff --no-index --binary"

	def execute
		if( FileTest.directory?(@srcPath) && FileTest.directory?(@dstPath) ) then
			puts "\n#{@srcPath}" if @verbose
			patchDir = @patchPath
			patchOutput = "#{patchDir}/0001.patch"
			exec_cmd = "#{DEF_EXEC_DIFF} -- #{Shellwords.escape(@srcPath)} #{Shellwords.escape(@dstPath)} > #{Shellwords.escape("#{patchOutput}.raw")}"
			ExecUtil.execCmd(exec_cmd, ".", false)
			_patchConverter(patchOutput+".raw", patchOutput)
			FileUtils.rm_f(patchOutput+".raw")
			if !File.size?(patchOutput) then
				FileUtils.rm_f(patchOutput)
			end
		else
			puts "\nSkipping... #{@srcPath} (not existed)" if @verbose
		end
	end

	def _replaceWords(aLine, replaceFrom, replaceTo)
		pos = aLine.index(replaceFrom)
		if pos then
			if pos != 0 then
				aLine = aLine[0..pos-1]+replaceTo+aLine[pos+replaceFrom.length...aLine.length]
			else
				aLine = replaceTo+aLine[pos+replaceFrom.length...aLine.length]
			end
		end
		return aLine
	end

	def _filterLine(aLine)
		if aLine.start_with?("diff --git a/") then
			aLine = _replaceWords(aLine, @srcPath, "")
			aLine = _replaceWords(aLine, @dstPath, "")
			aLine = _replaceWords(aLine, @srcPath, "")
			aLine = _replaceWords(aLine, @dstPath, "")
		elsif aLine.start_with?("--- ") then
			aLine = _replaceWords(aLine, @srcPath, "")
		elsif aLine.start_with?("+++ ") then
			aLine = _replaceWords(aLine, @dstPath, "")
		end

		return aLine
	end

	def _checkExcludePath(aLine)
		result = false

		path = aLine[13...aLine.length].strip
		pos = path.index(" ")
		path = path[0...pos] if pos
		@excludes.each do |anExclude|
			if path.start_with?(anExclude) || path.end_with?(anExclude) then
				result = true
				break
			end
		end

		return result
	end

	def _patchConverter(srcPath, dstPath)
		if srcPath && FileTest.exist?(srcPath) then
			fileReader = File.open(srcPath)
			fileWriter = File.open(dstPath, "w")
			if fileReader && fileWriter then
				ignoreSection = false
				while !fileReader.eof
					aLine = StrUtil.ensureUtf8(fileReader.readline)
					if aLine then
						aLine = _filterLine(aLine)
						ignoreSection = _checkExcludePath(aLine) if aLine.start_with?("diff --git a/")
						fileWriter.puts aLine if !ignoreSection
					end
				end
			end
			fileReader.close if fileReader
			fileWriter.close if fileWriter
		end
	end
end


#---- main --------------------------
options = {
	:verbose => false,
	:srcDir => nil,
	:dstDir => nil,
	:patchDir => ".",
	:exclude => ".git|.DS_Store"
}

opt_parser = OptionParser.new do |opts|
	opts.banner = "Usage: sourceDir targetDir -p patchOutputDir"

	opts.on("-v", "--verbose", "Enable verbose status output (default:#{options[:verbose]})") do
		options[:verbose] = true
	end

	opts.on("-p", "--patch=", "Specify patch output directory (default:#{options[:patchDir]})") do |patchDir|
		options[:patchDir] = patchDir
	end

	opts.on("-x", "--exclude=", "Specify exclude filter (default:#{options[:exclude]})") do |exclude|
		options[:exclude] = exclude
	end
end.parse!

if ARGV.length==2 then
	options[:srcDir] = ARGV[0]
	options[:dstDir] = ARGV[1]
else
	puts "sourceDir targetDir are required."
	exit(-1)
end

if !options[:srcDir] || !options[:dstDir] then
	puts "sourceDir targetDir are required."
	exit(-1)
end

options[:srcDir] = File.expand_path(options[:srcDir])
options[:dstDir] = File.expand_path(options[:dstDir])
options[:patchDir] = File.expand_path(options[:patchDir])

if !FileTest.directory?(options[:patchDir]) then
	FileUtil.ensureDirectory(options[:patchDir])
end

if( !FileTest.directory?(options[:srcDir]) || !FileTest.directory?(options[:dstDir]) || !FileTest.directory?(options[:patchDir]) ||
	(options[:srcDir] == options[:dstDir]) || (options[:srcDir] == options[:patchDir]) || (options[:patchDir] == options[:dstDir]) ) then
	puts "srcDir = #{options[:srcDir]}"
	puts "dstDir = #{options[:dstDir]}"
	puts "patchDir = #{options[:patchDir]}"
	puts ""
	puts "sourceDir, targetDir, patchDir are required as directory and different."
	exit(-1)
end

diffEngine = DiffWithGit.new(options[:srcDir], options[:dstDir], options[:patchDir], options[:exclude], options[:verbose])
diffEngine.execute()

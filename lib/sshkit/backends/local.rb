require 'open3'
require 'fileutils'
module SSHKit

  module Backend

    class Local < Abstract

      def initialize(_ = nil, &block)
        @host = Host.new(:local) # just for logging
        @block = block
      end

      def upload!(local, remote, options = {})
        if local.is_a?(String)
          FileUtils.cp(local, remote)
        else
          File.open(remote, "wb") do |f|
            IO.copy_stream(local, f)
          end
        end
      end

      def download!(remote, local=nil, options = {})
        if local.nil?
          FileUtils.cp(remote, File.basename(remote))
        else
          File.open(remote, "rb") do |f|
            IO.copy_stream(f, local)
          end
        end
      end

      private

      def execute_command(cmd)
        output << cmd

        cmd.started = Time.now

        Open3.popen3(cmd.to_command) do |stdin, stdout, stderr, wait_thr|
          stdout_thread = Thread.new do
            while line = stdout.gets do
              cmd.on_stdout(stdin, line)
              output << cmd
            end
          end

          stderr_thread = Thread.new do
            while line = stderr.gets do
              cmd.on_stderr(stdin, line)
              output << cmd
            end
          end

          stdout_thread.join
          stderr_thread.join

          cmd.exit_status = wait_thr.value.to_i
          cmd.clear_stdout_lines
          cmd.clear_stderr_lines

          output << cmd
        end
      end

    end
  end
end

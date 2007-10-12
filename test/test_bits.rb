require 'test/unit'
require "bits"
include BITS

#
# Unit tests for bits.rb
#
# Author::    Nicolas E. Rabenau (mailto:nerab@gmx.at)
# Copyright:: Copyright (c) 2005 Nicolas E. Rabenau
# License::   Distributed under the same terms as Ruby
#
class BITS_Test < Test::Unit::TestCase

	@@RND_CHARS = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

	#
	# create job with random name
	#
	def setup
		@jobName = self.class.name + "_" + BITS_Test.randomString(8)
		@job = Manager.createJob(@jobName)
	end

	#
	# remove test job
	#
	def teardown
		@job.cancel
	end

	#
	# test setting and reading the job's name
	#
	def test_name
		assert_equal(@jobName, @job.name)
	end

	#
	# test setting and reading the job's description
	#
	def test_description
		description = "A test job for bits.rb"
		@job.description = description
		assert_equal(description, @job.description)
	end

	#
	# tests the Manager's job listing by name
	#
	def test_joblist_by_name
		assert(0 < Manager.jobs.size)
		assert(Manager.jobs.has_key?(@jobName))
	end

	#
	# tests that the Manager's job listing by name returns all Jobs with duplicate names in an array
	#
	def test_joblist_by_name_with_duplicate_jobnames
		assert(Manager.jobs.has_key?(@jobName))
		j2 = Manager.createJob(@jobName)
		assert_equal(Array, Manager.jobs[@jobName].class)
		assert_equal(2, Manager.jobs[@jobName].size)
		j2.cancel
	end

	#
	# tests the Manager's job listing by id
	#
	def test_joblist_by_id
		assert(0 < Manager.jobs_by_id.size)
		assert(Manager.jobs_by_id.has_key?(@job.id))
	end

	#
	# test setting and reading the job's notify commandline
	#
	def test_notifycmdline
		notifycmdline = "net"
		notifycmdlineparams = "net send * BITS job #{@job.name} (#{@job.id}) successfully completed."
		@job.setnotifycmdline(notifycmdline, notifycmdlineparams)
		@job.description = "Testing notifycmdline"
		assert_equal("the notification command line is '#{notifycmdline}' '#{notifycmdline}'", @job.notifycmdline)
	end

	def test_status_created
		assert_equal("SUSPENDED", @job.state)
	end

	#
	# test resuming a job without an URL attached, must fail
	#
	def test_resume_empty
		@job.resume
		assert_equal("SUSPENDED", @job.state)
	end

	#
	# test resuming a job with an URL attached, must not be in suspended or cancelled state
	#
	def test_resume_nonempty
		@job.addFile("http://www.google.com", "c:\\temp\\google.com.html")
		@job.resume
		assert_not_equal("SUSPENDED", @job.state)
		assert_not_equal("CANCELLED", @job.state)
	end

	#
	# test attaching files to the job
	#
	def test_files
		@job.addFile("http://www.google.com", "c:\\temp\\google.com.html")
		@job.addFile("http://www.heise.de", "c:\\temp\\heise.de.html")
		assert_equal(@job.files[0].remote_url, "http://www.google.com")
		assert_equal(@job.files[0].local_name, "c:\\temp\\google.com.html")
		assert_equal(@job.files[1].remote_url, "http://www.heise.de")
		assert_equal(@job.files[1].local_name, "c:\\temp\\heise.de.html")
	end

private

	#
	# returns a String of defined length, made of random characters and numbers
	#
	def BITS_Test.randomString(length)
		retVal = Array.new
		for i in 0..length
			retVal[i] = @@RND_CHARS[rand(@@RND_CHARS.length)]
		end

		retVal.to_s
	end
end

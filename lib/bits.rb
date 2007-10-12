#
# An interface for the "Background Intelligent Transfer Service" (BITS) in MS Windows
#
# A more decent way to interface with BITS would be the COM interface it provides. I did not get it to work, so I had to revert to pasing the bitsadmin command.
#
# Prereqs (formally stated in ../bits.gemspec):
# - "Background Intelligent Transfer Service" (BITS) für Windows (KB842773)
# - bitsadmin tool, available at http://www.microsoft.com/downloads/details.aspx?amp;displaylang=en&familyid=49AE8576-9BB9-4126-9761-BA8011FABF38&displaylang=en
#
# Author::    Nicolas E. Rabenau (mailto:nerab@gmx.at)
# Copyright:: Copyright (c) 2005 Nicolas E. Rabenau
# License::   Distributed under the same terms as Ruby
#
module BITS
	#
	# the basic bitsadmin string that is used in all methods
	#
	BITSADMIN = "bitsadmin /rawreturn /nowrap"

	#
	# The BITS Manager bundles all static BITS operations that are independent from an individual job
	#
	class Manager

		#
		# returns a hash of all BITS jobs where the job's name is the key and the Job itself is the value. If there is more
		# than one job with the same name the value is an array of all jobs with that name.
		#
		def Manager.jobs
			jobs = Hash.new

			for jobString in `#{BITS::BITSADMIN} /list`.split(/\n/)
				job = Job.new(jobString)

				# a job's name is not guaranteed to be unique
				if jobs[job.name].nil?
					# value has not been assigned before
					jobs[job.name] = job
				else
					if jobs[job.name].is_a? Array
						# value already contains an array
						jobs[job.name] << job
					elsif jobs[job.name].is_a? Job
						# value contains a Job
						existingValue = jobs[job.name]
						jobs[job.name] = Array.new
						jobs[job.name] << existingValue
						jobs[job.name] << job
					else
						# should never happen. If it does, there is something terribly wrong, so we bail out fast
						raise "Unexpected class of value (#{jobs[job.name].class}) for jobs['#{job.name}']"
					end
				end
			end

			jobs
		end

		#
		# returns a hash of all BITS jobs where the job's id is the key and the Job itself is the value
		#
		def Manager.jobs_by_id
			jobs = Hash.new

			for jobString in `#{BITS::BITSADMIN} /list`.split(/\n/)
				job = Job.new(jobString)
				jobs[job.id] = job
			end

			jobs
		end

		#
		# create a new job with name
		#
		# It is arguable whether this method should be Job.create or Manager.createJob. I decided to use the latter.
		#
		def Manager.createJob(name)
			if "" == name
				raise "Job name missing"
			end

			Job.new(`#{BITS::BITSADMIN} /create "#{name}"`)
		end

		#
		# deletes all jobs
		#
		def Manager.cancelAllJobs
			`#{BITS::BITSADMIN} /reset`
		end

		#
		# returns the version number of the underlying BITS
		#
		# For troubleshooting, we could use "bitsadmin /util /version /verbose"
		#
		def Manager.version
			parsed = `bitsadmin`.scan /\d\.\d/
			parsed[0]
		end
	end

	#
	# Models the description of a downloadable file, consisting of an URL and the local name where the result is going to be stored
	#
	class FileDescriptor
		attr_accessor :remote_url, :local_name, :bytes_transferred, :bytes_total

		#
		# builds a new FileDescription with the URL and the optional local name
		#
		def initialize(url, local_name = nil)
			@remote_url = url
			@local_name = local_name
			@bytes_transferred = 0
			@bytes_total = 'UNKNOWN'
		end

		def to_s
			"#{@remote_url} ->  #{@local_name}"
		end
	end

	#
	# Models a BITS job
	#
	# A job can be modified through set methods, changes will be effective immediately.
	#
	class Job

		# descriptions taken from http://msdn.microsoft.com/library/default.asp?url=/library/en-us/bits/bits/bits_reference.asp
		STATE_QUEUED			= "QUEUED"			# Specifies that the job is in the queue and waiting to run. If a user logs off while their job is transferring, the job transitions to the queued state.
		STATE_CONNECTING		= "CONNECTING" 		# Specifies that BITS is trying to connect to the server. If the connection succeeds, the state of the job becomes JOB_STATE_TRANSFERRING; otherwise, the state becomes JOB_STATE_TRANSIENT_ERROR.
		STATE_TRANSFERRING	= "TRANSFERRING" 	# Specifies that BITS is transferring data for the job.
		STATE_SUSPENDED		= "SUSPENDED" 		# Specifies that the job is suspended (paused). To suspend a job, call the IBackgroundCopyJob::Suspend method. BITS automatically suspends a job when it is created. The job remains suspended until you call the IBackgroundCopyJob::Resume, IBackgroundCopyJob::Complete, or IBackgroundCopyJob::Cancel method.
		STATE_ERROR			= "ERROR" 			# Specifies that a non-recoverable error occurred (the service is unable to transfer the file). If the error, such as an access-denied error, can be corrected, call the IBackgroundCopyJob::Resume method after the error is fixed. However, if the error cannot be corrected, call the IBackgroundCopyJob::Cancel method to cancel the job, or call the IBackgroundCopyJob::Complete method to accept the portion of a download job that transferred successfully.
		STATE_TRANSIENT_ERROR	= "TRANSIENT_ERROR"	# Specifies that a recoverable error occurred. BITS will retry jobs in the transient error state based on the retry interval you specify (see IBackgroundCopyJob::SetMinimumRetryDelay). The state of the job changes to JOB_STATE_ERROR if the job fails to make progress (see IBackgroundCopyJob::SetNoProgressTimeout). BITS does not retry the job if a network disconnect or disk lock error occurred (for example, chkdsk is running) or the MaxInternetBandwidth Group Policy is zero.
		STATE_TRANSFERRED		= "TRANSFERRED" 	# Specifies that your job was successfully processed. You must call the IBackgroundCopyJob::Complete method to acknowledge completion of the job and to make the files available to the client.
		STATE_ACKNOWLEDGED	= "ACKNOWLEDGED"	# Specifies that you called the IBackgroundCopyJob::Complete method to acknowledge that your job completed successfully.
		STATE_CANCELLED		= "CANCELLED" 		# Specifies that you called the IBackgroundCopyJob::Cancel method to cancel the job (remove the job from the transfer queue).

		PRIORITY_FOREGROUND	= "FOREGROUND"	# Transfers the job in the foreground. Foreground transfers compete for network bandwidth with other applications, which can impede the user's network experience. This is the highest priority level.
		PRIORITY_HIGH		= "HIGH"		# Transfers the job in the background with a high priority. Background transfers use idle network bandwidth of the client to transfer files. This is the highest background priority level.
		PRIORITY_NORMAL		= "NORMAL"		# Transfers the job in the background with a normal priority. Background transfers use idle network bandwidth of the client to transfer files. This is the default priority level.
		PRIORITY_LOW			= "LOW"			# Transfers the job in the background with a low priority. Background transfers use idle network bandwidth of the client to transfer files. This is the lowest background priority level.

		#
		# used to refer to the job in BITS (primary key)
		#
		attr_reader :id

		#
		# builds a new Job from the supplied id. The job must already exist in BITS
		#
		# Ideally this method would have only module visibility in order to prevent instantiations of a job outside Manager.createJob
		#
		def initialize(job_id)
			if %r!([A-Z0-9]{8}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{12})! =~ job_id
				@id = $1
			else
				raise JobParseException, "Unable to parse '#{job_id}' into a job description. Maybe the format has changed?"
			end
		end

		def files
			output = `#{BITS::BITSADMIN} /listfiles {#{@id}}`

			# bitsadmin typically produces something like this:
			# 0 / UNKNOWN WORKING http://remote -> c:\temp\local.file

			files = Array.new

			for line in output.split(/\n/)
				if %r!(\d+) / ((\d+)|UNKNOWN) WORKING (.*) -> (.*)! =~ line
					# print "found 1: >#{$1}< 2: >#{$2}< 3: >#{$3}< 4: >#{$4}< 5: >#{$5}<"
					p = FileDescriptor.new($4, $5)
					p.bytes_transferred = $1
					p.bytes_total = $2
					files << p
				else
					raise FileDescriptorParseException, "Unable to parse '#{output}' into a file descriptor. Maybe the format has changed?"
				end
			end

			files
		end

		#
		# adds a file to be downloaded and the local name for the file to the job
		#
		def addFile(url, local_name)
			`bitsadmin /rawreturn /addfile {#{@id}} #{url} #{local_name}`
		end

		#
		# suspends the job
		#
		def suspend
			`#{BITS::BITSADMIN} /suspend {#{@id}}`
		end

		#
		# resumes the job
		#
		def resume
			`#{BITS::BITSADMIN} /resume {#{@id}}`
		end

		#
		# cancels the job
		#
		def cancel
			`#{BITS::BITSADMIN} /cancel {#{@id}}`
		end

		#
		# completes the job
		#
		def complete
			`#{BITS::BITSADMIN} /complete {#{@id}}`
		end

		# returns the job's type
		def type
			`#{BITS::BITSADMIN} /gettype {#{@id}}`
		end

		# returns the job's ACL propagation flags
		def aclflags
			`#{BITS::BITSADMIN} /getaclflags {#{@id}}`
		end

		# returns the size of the job
		def bytestotal
			`#{BITS::BITSADMIN} /getbytestotal {#{@id}}`
		end

		# returns the number of bytes transferred
		def bytestransferred
			`#{BITS::BITSADMIN} /getbytestransferred {#{@id}}`
		end

		# returns the number of files in the job
		def filestotal
			`#{BITS::BITSADMIN} /getfilestotal {#{@id}}`
		end

		# returns the number of files transferred
		def filestransferred
			`#{BITS::BITSADMIN} /getfilestransferred {#{@id}}`
		end

		# returns the job's creation time
		def creationtime
			`#{BITS::BITSADMIN} /getcreationtime {#{@id}}`
		end

		# returns the job's modification time
		def modificationtime
			`#{BITS::BITSADMIN} /getmodificationtime {#{@id}}`
		end

		# returns the job's completion time
		def completiontime
			`#{BITS::BITSADMIN} /getcompletiontime {#{@id}}`
		end

		# returns the job's state
		def state
			`#{BITS::BITSADMIN} /getstate {#{@id}}`
		end

		# returns detailed error information
		def error
			`#{BITS::BITSADMIN} /geterror {#{@id}}`
		end

		# returns the job's owner
		def owner
			`#{BITS::BITSADMIN} /getowner {#{@id}}`
		end

		# returns the job's display name
		def name
			`#{BITS::BITSADMIN} /getdisplayname {#{@id}}`
		end

		# returns the job's description
		def description
			`#{BITS::BITSADMIN} /getdescription {#{@id}}`
		end

		# returns the job's priority
		def priority
			`#{BITS::BITSADMIN} /getpriority {#{@id}}`
		end

		# returns the notify flags
		def notifyflags
			`#{BITS::BITSADMIN} /getnotifyflags {#{@id}}`
		end

		# Determines if notify interface is registered
		def notifyinterface
			`#{BITS::BITSADMIN} /getnotifyinterface {#{@id}}`
		end

		# returns the retry delay in seconds
		def minretrydelay
			`#{BITS::BITSADMIN} /getminretrydelay {#{@id}}`
		end

		# returns the no progress timeout in seconds
		def noprogresstimeout
			`#{BITS::BITSADMIN} /getnoprogresstimeout {#{@id}}`
		end

		# returns an error count for the job
		def errorcount
			`#{BITS::BITSADMIN} /geterrorcount {#{@id}}`
		end

		# returns the proxy usage setting
		def proxyusage
			`#{BITS::BITSADMIN} /getproxyusage {#{@id}}`
		end

		# returns the proxy list
		def proxylist
			`#{BITS::BITSADMIN} /getproxylist {#{@id}}`
		end

		# returns the proxy bypass list
		def proxybypasslist
			`#{BITS::BITSADMIN} /getproxybypasslist {#{@id}}`
		end

		# returns the job's notification command line
		def notifycmdline
			`#{BITS::BITSADMIN} /getnotifycmdline {#{@id}}`
		end

		# returns a String representation of the job
		def to_s
			`#{BITS::BITSADMIN} /info {#{@id}}`
		end

# attribute writers

		# sets the ACL propagation flags for the job
		def aclflags=(acl_flags)
			`#{BITS::BITSADMIN} /setaclflags {#{@id}} #{acl_flags}`
		end

		# sets the job display name
		def name=(display_name)
			`#{BITS::BITSADMIN} /setdisplayname {#{@id}} \"#{display_name}\"`
		end

		# sets the job description
		def description=(description)
			`#{BITS::BITSADMIN} /setdescription {#{@id}} \"#{description}\"`
		end

		# sets the job priority
		def priority=(priority)
			`#{BITS::BITSADMIN} /setpriority {#{@id}} #{priority}`
		end

		# sets the notify flags
		def notifyflags=(notify_flags)
			`#{BITS::BITSADMIN} /setnotifyflags {#{@id}} #{notify_flags}`
		end

		# sets the retry delay in seconds
		def minretrydelay=(retry_delay)
			`#{BITS::BITSADMIN} /setminretrydelay {#{@id}} #{retry_delay}`
		end

		# sets the no progress timeout in seconds
		def noprogresstimeout=(timeout)
			`#{BITS::BITSADMIN} /setnoprogresstimeout {#{@id}} #{timeout}`
		end

		# sets the proxy usage
		def proxysettings=(usage)
			`#{BITS::BITSADMIN} /setproxysettings {#{@id}} #{usage}`
		end

		# sets a program to execute for notification, and optionally parameters. The program name and parameters can be NULL.
		# IMPORTANT: if parameters are non-NULL, then the program name should be the first parameter.
		#
		# For some reason I didn't get this assignment operation to work with more than a single parameter, therefore I made
		# it a "setXxx" operation. Not elegant, but it works.
		#
		def setnotifycmdline(program_name, program_parameters = "")
			`#{BITS::BITSADMIN} /setnotifycmdline {#{@id}} #{program_name} \"#{program_parameters}\"`
		end

		# adds credentials to a job. <target> may be either SERVER or PROXY, <scheme> may be BASIC, DIGEST, NTLM, NEGOTIATE, or PASSPORT.
		def credentials=(target, scheme, username, password)
			`#{BITS::BITSADMIN} /setcredentials {#{@id}} #{target} #{scheme} #{username} #{password}`
		end
	end

	#
	# Generic parse exception, base class for concrete parse exceptions
	#
	class ParseException < Exception

	end

	#
	# Exception that occurs in case parsing a Job specification fails
	#
	class JobParseException < ParseException

	end

	#
	# Exception that occurs in case parsing a FileDescriptor specification fails
	#
	class FileDescriptorParseException < ParseException

	end
end

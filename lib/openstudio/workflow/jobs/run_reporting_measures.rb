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

# Run reporting measures and execute scripts to post-process objective functions and results on the filesystem
class RunReportingMeasures < OpenStudio::Workflow::Job

  require 'csv'
  require 'ostruct'
  require 'openstudio/workflow/util'
  include OpenStudio::Workflow::Util::Model
  include OpenStudio::Workflow::Util::Measure
  include OpenStudio::Workflow::Util::PostProcess

  def initialize(input_adapter, output_adapter, registry, options = {})
    defaults = {
      load_simulation_osm: false,
      load_simulation_idf: false,
      load_simulation_sql: false
    }
    options = defaults.merge(options)
    super
  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"
    @logger.info 'RunPostProcess Retrieving datapoint and problem'

    # Ensure output_attributes is initialized in the registry
    @registry.register(:output_attributes) { {} } unless @registry[:output_attributes]

    # Load simulation files as required
    if @options[:load_simulation_osm]
      osm_path = File.absolute_path(File.join(@registry[:run_dir], 'in.osm'))
      @logger.info "Attempting to load #{osm_path}"
      @registry.register(:model) { load_osm('.', osm_path) }
      fail "Unable to load #{osm_path}" unless @registry[:model]
      @logger.info "Successfully loaded #{osm_path}"
    end
    if @options[:load_simulation_idf]
      idf_path = File.absolute_path(File.join(@registry[:run_dir], 'in.idf'))
      @logger.info "Attempting to load #{idf_path}"
      @registry.register(:model_idf) { load_idf('.', idf_path) }
      fail "Unable to load #{idf_path}" unless @registry[:model_idf]
      @logger.info "Successfully loaded #{idf_path}"
    end
    if @options[:load_simulation_sql]
      @registry.register(:sql) { File.absolute_path(File.join(@registry[:run_dir], 'eplusout.sql')) }
      @logger.info "Registered the sql filepath as #{@registry[:sql]}"
    end

    # Translate the eplustbl.csv into standard_report_legacy.json
    translate_csv_to_json @registry[:run_dir]

    # Apply reporting measures
    @options[:output_adapter] = @output_adapter
    @logger.info 'Beginning to execute Reporting measures.'
    apply_measures(:reporting, @registry, @options)
    @logger.info('Finished applying Reporting measures.')

    # Send the updated measure_attributes to the output adapter
    @logger.info 'Communicating measures output attributes to the output adapter'
    @output_adapter.communicate_measure_attributes @registry[:output_attributes]

    # Parse the files generated by the local output adapter
    results, objective_functions = run_extract_inputs_and_outputs @registry[:run_dir]

    # Send the objective function results to the output adapter
    @logger.info "Objective Function JSON is #{objective_functions}"
    @output_adapter.communicate_objective_function objective_functions

    # Send the general results to the output adapter
    @output_adapter.communicate_results(@registry[:run_dir], results)

    nil
  end
end

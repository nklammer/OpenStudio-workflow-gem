# frozen_string_literal: true

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

require_relative './../../spec_helper'
require 'json-schema'

describe 'OSW Integration' do
  it 'should run empty OSW file' do
    osw_path = File.join(__FILE__, './../../../files/empty_seed_osw/empty.osw')
    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run compact OSW file' do
    osw_path = File.expand_path('../../files/compact_osw/compact.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  it 'should run compact OSW file in m and w and p mode' do
    osw_path = File.expand_path('../../files/compact_mwp_osw/compact_mwp.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    osw_out_m_path = osw_path.gsub(File.basename(osw_path), 'out_m.osw')
    osw_out_w_path = osw_path.gsub(File.basename(osw_path), 'out_w.osw')
    osw_out_p_path = osw_path.gsub(File.basename(osw_path), 'out_p.osw')
    data_point_out_path = osw_path.gsub(File.basename(osw_path), 'run/data_point_out.json')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false
    FileUtils.rm_rf(osw_out_m_path) if File.exist?(osw_out_m_path)
    expect(File.exist?(osw_out_m_path)).to eq false
    FileUtils.rm_rf(osw_out_w_path) if File.exist?(osw_out_w_path)
    expect(File.exist?(osw_out_w_path)).to eq false
    FileUtils.rm_rf(osw_out_p_path) if File.exist?(osw_out_p_path)
    expect(File.exist?(osw_out_p_path)).to eq false
    FileUtils.rm_rf(data_point_out_path) if File.exist?(data_point_out_path)
    expect(File.exist?(data_point_out_path)).to eq false

    # run measures only
    run_options = {
      debug: true,
      jobs: [
        { state: :queued, next_state: :initialization, options: { initial: true } },
        { state: :initialization, next_state: :os_measures, job: :RunInitialization,
          file: 'openstudio/workflow/jobs/run_initialization.rb', options: {} },
        { state: :os_measures, next_state: :translator, job: :RunOpenStudioMeasures,
          file: 'openstudio/workflow/jobs/run_os_measures.rb', options: {} },
        { state: :translator, next_state: :ep_measures, job: :RunTranslation,
          file: 'openstudio/workflow/jobs/run_translation.rb', options: {} },
        { state: :ep_measures, next_state: :finished, job: :RunEnergyPlusMeasures,
          file: 'openstudio/workflow/jobs/run_ep_measures.rb', options: {} },
        { state: :postprocess, next_state: :finished, job: :RunPostprocess,
          file: 'openstudio/workflow/jobs/run_postprocess.rb', options: {} },
        { state: :finished },
        { state: :errored }
      ]
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true
    FileUtils.cp(osw_out_path, osw_out_m_path)

    # DLM: TODO, the following line fails currently because the results hash is only populated in run_reporting_measures
    # with a call to run_extract_inputs_and_outputs, seems like this should be called after running model and e+ measures
    # expect(File.exist?(data_point_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to eq 4
    expect(osw_out[:steps][0][:result]).to_not be_nil
    expect(osw_out[:steps][0][:result][:step_initial_condition]).to be_nil
    expect(osw_out[:steps][0][:result][:step_result]).to eq 'Skip'
    expect(osw_out[:steps][1][:result]).to_not be_nil
    expect(osw_out[:steps][1][:result][:step_initial_condition]).to eq 'IncreaseInsulationRValueForRoofsByPercentage'
    expect(osw_out[:steps][1][:result][:step_result]).to eq 'Success'
    expect(osw_out[:steps][2][:result]).to_not be_nil
    expect(osw_out[:steps][2][:result][:step_initial_condition]).to eq 'SetEnergyPlusInfiltrationFlowRatePerFloorArea'
    expect(osw_out[:steps][2][:result][:step_result]).to eq 'Success'
    expect(osw_out[:steps][3][:result]).to be_nil

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false
    FileUtils.rm_rf(data_point_out_path) if File.exist?(data_point_out_path)
    expect(File.exist?(data_point_out_path)).to eq false

    # run
    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true
    FileUtils.cp(osw_out_path, osw_out_w_path)

    expect(File.exist?(data_point_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to eq 4
    expect(osw_out[:steps][0][:result]).to_not be_nil
    expect(osw_out[:steps][0][:result][:step_initial_condition]).to be_nil
    expect(osw_out[:steps][0][:result][:step_result]).to eq 'Skip'
    expect(osw_out[:steps][1][:result]).to_not be_nil
    expect(osw_out[:steps][1][:result][:step_initial_condition]).to eq 'IncreaseInsulationRValueForRoofsByPercentage'
    expect(osw_out[:steps][1][:result][:step_result]).to eq 'Success'
    expect(osw_out[:steps][2][:result]).to_not be_nil
    expect(osw_out[:steps][2][:result][:step_initial_condition]).to eq 'SetEnergyPlusInfiltrationFlowRatePerFloorArea'
    expect(osw_out[:steps][2][:result][:step_result]).to eq 'Success'
    expect(osw_out[:steps][3][:result]).to_not be_nil
    expect(osw_out[:steps][3][:result][:step_initial_condition]).to eq 'DencityReports'
    expect(osw_out[:steps][3][:result][:step_result]).to eq 'Success'

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false
    FileUtils.rm_rf(data_point_out_path) if File.exist?(data_point_out_path)
    expect(File.exist?(data_point_out_path)).to eq false

    # run post process
    run_options = {
      debug: true,
      preserve_run_dir: true,
      jobs: [
        { state: :queued, next_state: :initialization, options: { initial: true } },
        { state: :initialization, next_state: :reporting_measures, job: :RunInitialization,
          file: 'openstudio/workflow/jobs/run_initialization.rb', options: {} },
        { state: :reporting_measures, next_state: :postprocess, job: :RunReportingMeasures,
          file: 'openstudio/workflow/jobs/run_reporting_measures.rb', options: {} },
        { state: :postprocess, next_state: :finished, job: :RunPostprocess,
          file: 'openstudio/workflow/jobs/run_postprocess.rb', options: {} },
        { state: :finished },
        { state: :errored }
      ]
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true
    FileUtils.cp(osw_out_path, osw_out_p_path)

    expect(File.exist?(data_point_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps][0][:result]).to be_nil
    expect(osw_out[:steps][1][:result]).to be_nil
    expect(osw_out[:steps][2][:result]).to be_nil
    expect(osw_out[:steps][3][:result]).to_not be_nil
    expect(osw_out[:steps][3][:result][:step_initial_condition]).to eq 'DencityReports'
    expect(osw_out[:steps][3][:result][:step_result]).to eq 'Success'
    expect(osw_out[:steps][3][:result][:step_final_condition]).to eq 'DEnCity Report generated successfully.'
  end

  it 'should run an extended OSW file' do
    osw_path = File.expand_path('../../files/extended_osw/example/workflows/extended.osw', __dir__)
    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run an alternate path OSW file' do
    osw_path = File.expand_path('../../files/alternate_paths/osw_and_stuff/in.osw', __dir__)
    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run OSW file with skips' do
    osw_path = File.expand_path('../../files/skip_osw/skip.osw', __dir__)
    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run OSW file with handle arguments' do
    osw_path = File.expand_path('../../files/handle_args_osw/handle_args.osw', __dir__)
    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run OSW with output requests file' do
    osw_path = File.expand_path('../../files/output_request_osw/output_request.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end

    idf_out_path = osw_path.gsub(File.basename(osw_path), 'in.idf')

    expect(File.exist?(idf_out_path)).to eq true

    workspace = OpenStudio::Workspace.load(idf_out_path)
    expect(workspace.empty?).to eq false

    workspace = workspace.get

    targets = {}
    targets['Electricity:Facility'] = false
    targets['Gas:Facility'] = false
    targets['District Cooling Chilled Water Rate'] = false
    targets['District Cooling Mass Flow Rate'] = false
    targets['District Cooling Inlet Temperature'] = false
    targets['District Cooling Outlet Temperature'] = false
    targets['District Heating Hot Water Rate'] = false
    targets['District Heating Mass Flow Rate'] = false
    targets['District Heating Inlet Temperature'] = false
    targets['District Heating Outlet Temperature'] = false

    workspace.getObjectsByType('Output:Variable'.to_IddObjectType).each do |object|
      name = object.getString(1)
      expect(name.empty?).to eq false
      name = name.get
      targets[name] = true
    end

    targets.each_key do |key|
      expect(targets[key]).to eq true
    end

    # make sure that the reports exist
    report_filename = File.join(File.dirname(osw_path), 'reports', 'dencity_reports_report_timeseries.csv')
    expect(File.exist?(report_filename)).to eq true
    report_filename = File.join(File.dirname(osw_path), 'reports', 'openstudio_results_report.html')
    expect(File.exist?(report_filename)).to eq true
    report_filename = File.join(File.dirname(osw_path), 'reports', 'eplustbl.html')
    expect(File.exist?(report_filename)).to eq true
  end

  it 'should run OSW file with web adapter' do
    require 'openstudio/workflow/adapters/output/web'

    osw_path = File.expand_path('../../files/web_osw/web.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    run_dir = File.join(File.dirname(osw_path), 'run')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    output_adapter = OpenStudio::Workflow::OutputAdapter::Web.new(output_directory: run_dir, url: 'http://www.example.com')

    run_options = {
      debug: true,
      output_adapter: output_adapter
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  it 'should run OSW file with socket adapter' do
    require 'openstudio/workflow/adapters/output/socket'

    osw_path = File.expand_path('../../files/socket_osw/socket.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    run_dir = File.join(File.dirname(osw_path), 'run')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    port = 2000
    content = ''

    server = TCPServer.open('localhost', port)
    t = Thread.new do
      while client = server.accept
        while line = client.gets
          content += line
        end
      end
    end

    output_adapter = OpenStudio::Workflow::OutputAdapter::Socket.new(output_directory: run_dir, port: port)

    run_options = {
      debug: true,
      output_adapter: output_adapter
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    Thread.kill(t)

    # puts "content = #{content}"

    expect(content).to match(/Applying IncreaseInsulationRValueForExteriorWallsByPercentage/)
    expect(content).to match(/For construction'EXTERIOR-WALL adj exterior wall insulation', material'Wood-Framed - 4 in. Studs - 16 in. OC - R-11 Cavity Insulation_R-value 30.0% increase' was altered./)
    expect(content).to match(/Applied IncreaseInsulationRValueForExteriorWallsByPercentage/)
    expect(content).to match(/Applying IncreaseInsulationRValueForRoofsByPercentage/)
    expect(content).to match(/The building had 1 roof constructions: EXTERIOR-ROOF \(R-31\.2\)/)
    expect(content).to match(/Applied IncreaseInsulationRValueForRoofsByPercentage/)
    expect(content).to match(/Applying SetEnergyPlusInfiltrationFlowRatePerFloorArea/)
    expect(content).to match(/The building finished with flow per zone floor area values ranging from 10\.76 to 10\.76/)
    expect(content).to match(/Applied SetEnergyPlusInfiltrationFlowRatePerFloorArea/)
    expect(content).to match(/Starting state initialization/)
    # expect(content).to match(/Processing Data Dictionary/)
    # expect(content).to match(/Writing final SQL reports/)
    expect(content).to match(/Applying DencityReports/)
    expect(content).to match(/DEnCity Report generated successfully/)
    expect(content).to match(/Saving Dencity metadata csv file/)
    expect(content).to match(/Applied DencityReports/)
    expect(content).to match(/Complete/)

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  it 'should run OSW file with no epw file' do
    osw_path = File.expand_path('../../files/no_epw_file_osw/no_epw_file.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    run_dir = File.join(File.dirname(osw_path), 'run')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  it 'should run OSW file in measure only mode' do
    osw_path = File.expand_path('../../files/measures_only_osw/measures_only.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    idf_out_path = osw_path.gsub(File.basename(osw_path), 'run/in.idf')
    osm_out_path = osw_path.gsub(File.basename(osw_path), 'run/in.osm')
    run_dir = File.join(File.dirname(osw_path), 'run')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    FileUtils.rm_rf(idf_out_path) if File.exist?(idf_out_path)
    expect(File.exist?(idf_out_path)).to eq false

    FileUtils.rm_rf(osm_out_path) if File.exist?(osm_out_path)
    expect(File.exist?(osm_out_path)).to eq false

    run_options = {}
    # run_options = {
    #    debug: true
    # }
    run_options[:jobs] = [
      { state: :queued, next_state: :initialization, options: { initial: true } },
      { state: :initialization, next_state: :os_measures, job: :RunInitialization,
        file: 'openstudio/workflow/jobs/run_initialization.rb', options: {} },
      { state: :os_measures, next_state: :translator, job: :RunOpenStudioMeasures,
        file: 'openstudio/workflow/jobs/run_os_measures.rb', options: {} },
      { state: :translator, next_state: :ep_measures, job: :RunTranslation,
        file: 'openstudio/workflow/jobs/run_translation.rb', options: {} },
      { state: :ep_measures, next_state: :preprocess, job: :RunEnergyPlusMeasures,
        file: 'openstudio/workflow/jobs/run_ep_measures.rb', options: {} },
      { state: :preprocess, next_state: :postprocess, job: :RunPreprocess,
        file: 'openstudio/workflow/jobs/run_preprocess.rb', options: {} },
      { state: :postprocess, next_state: :finished, job: :RunPostprocess,
        file: 'openstudio/workflow/jobs/run_postprocess.rb', options: {} },
      { state: :finished },
      { state: :errored }
    ]
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true
    expect(File.exist?(idf_out_path)).to eq true
    expect(File.exist?(osm_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  it 'should run OSW with display name or value for choice arguments' do
    osw_path = File.expand_path('../../files/value_or_displayname_choice_osw/value_or_displayname_choice.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  # XcelEDAReportingandQAQC measure not work with OS 3.1
  # it 'should error out nicely' do
  # osw_path = File.expand_path('../../files/reporting_measure_error/reporting_measure_error.osw', __dir__)
  # osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

  # FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
  # expect(File.exist?(osw_out_path)).to eq false

  # run_options = {
  # debug: true
  # }
  # k = OpenStudio::Workflow::Run.new osw_path, run_options
  # expect(k).to be_instance_of OpenStudio::Workflow::Run
  # expect(k.run).to eq :errored

  # expect(File.exist?(osw_out_path)).to eq true

  # osw_out = nil
  # File.open(osw_out_path, 'r') do |file|
  # osw_out = JSON.parse(file.read, symbolize_names: true)
  # end

  # expect(osw_out).to be_instance_of Hash
  # expect(osw_out[:completed_status]).to eq 'Fail'
  # expect(osw_out[:steps]).to be_instance_of Array
  # expect(osw_out[:steps].size).to be > 0
  # osw_out[:steps].each do |step|
  # expect(step[:result]).to_not be_nil
  # # Only the EDA reporting measure step is supposed to have failed
  # if step[:measure_dir_name] == 'Xcel EDA Reporting and QAQC'
  # expect(step[:result][:step_result]).to eq 'Fail'
  # else
  # expect(step[:result][:step_result]).to eq 'Success'
  # end
  # end

  # expected_r = /Peak Demand timeseries \(Electricity:Facility at zone timestep\) could not be found, cannot determine the informati(no|on) needed to calculate savings or incentives./
  # expect(osw_out[:steps].last[:result][:step_errors].last).to match expected_r

  # # TODO: Temporary comment
  # # Not sure why the in.idf ends up there at the root? Shouldn't it just be
  # # in run/in.idf?
  # idf_out_path = osw_path.gsub(File.basename(osw_path), 'in.idf')
  # expect(File.exist?(idf_out_path)).to eq true

  # # even if it fails, make sure that we save off the datapoint.zip
  # # It shouldn't be in the wrong location at root next to OSW
  # zip_path = osw_path.gsub(File.basename(osw_path), 'data_point.zip')
  # expect(File.exist?(zip_path)).to eq false
  # # It should be under run/
  # zip_path = File.join(File.dirname(osw_path), 'run', 'data_point.zip')
  # expect(File.exist?(zip_path)).to eq true
  # end

  it 'should raise error when full measure directory path specified' do
    osw_path = File.expand_path('../../files/full_measure_dir_osw/full_measure_dir.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }

    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :errored
    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Fail'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be == 1

    expect(osw_out[:steps][0]).to_not be_nil

    if osw_out[:steps][0][:measure_dir_name] == '/OpenStudio-workflow-gem/spec/files/full_measure_dir_osw/measures/'
      expect(osw_out[:steps][0][:result][:step_warnings]).to eq 'measure_dir_name should not be a full path. It should be a relative path to the measure directory or the name of the measure directory containing the measure.rb file.'
    end
  end

  it 'should error out while copying html reports' do
    osw_path = File.expand_path('../../files/reporting_measure_raise/reporting_measure_raise.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :errored

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Fail'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
      # Only the broken reporting measure step is supposed to have failed
      if step[:measure_dir_name] == 'purposefully_broken_reporting_measure'
        expect(step[:result][:step_result]).to eq 'Fail'
      else
        expect(step[:result][:step_result]).to eq 'Success'
      end
    end

    expected_r = /I'm purposefully breaking the reporting! Before the report was already created!/
    expect(osw_out[:steps].last[:result][:step_errors].last).to match expected_r

    idf_out_path = File.join(File.dirname(osw_path), 'run', 'in.idf')
    expect(File.exist?(idf_out_path)).to eq true

    zip_path = File.join(File.dirname(osw_path), 'run', 'data_point.zip')
    expect(File.exist?(zip_path)).to eq true

    # Tests that we find the two reports that actually worked fine:
    # eplus + openstudio_results.
    # The broken one shouldn't be there since I raise before it
    reports_dir_path = File.join(File.dirname(osw_path), 'reports')
    html_reports = Dir.glob(File.join(reports_dir_path, '*.html'))
    html_reports_names = html_reports.map { |f| File.basename(f) }
    expect(html_reports_names.size).to eq 2
    expect(html_reports_names.include?('eplustbl.html')).to eq true
    expect(html_reports_names.include?('openstudio_results_report.html')).to eq true
  end

  it 'should allow passing model to arguments() method of ReportingMeasure' do
    osw_path = File.expand_path('../../files/reporting_measure_arguments_model/reporting_measure_arguments_model.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be 1
    step = osw_out[:steps][0]
    expect(step[:measure_dir_name]).to eq 'reporting_measure_that_takes_model_in_arguments'
    expect(step[:result][:step_result]).to eq 'Success'

    expect(step[:result][:step_info]).to include('Getting argument add_for_thermal_zones')
    expect(step[:result][:step_info]).to include('Argument add_for_thermal_zones is true')

    idf_out_path = File.join(File.dirname(osw_path), 'run', 'in.idf')
    expect(File.exist?(idf_out_path)).to eq true

    zip_path = File.join(File.dirname(osw_path), 'run', 'data_point.zip')
    expect(File.exist?(zip_path)).to eq true

    # Tests that we find the two reports that actually worked fine:
    # eplus + our reporting measure.
    reports_dir_path = File.join(File.dirname(osw_path), 'reports')
    html_reports = Dir.glob(File.join(reports_dir_path, '*.html'))
    html_reports_names = html_reports.map { |f| File.basename(f) }
    expect(html_reports_names.size).to eq 2
    expect(html_reports_names.include?('eplustbl.html')).to eq true
    expect(html_reports_names.include?('reporting_measure_that_takes_model_in_arguments_report.html')).to eq true
  end

  # XcelEDAReportingandQAQC no workie
  # it 'should associate results with the correct step' do
  # (1..2).each do |i|
  # osw_path = File.expand_path("./../../../files/results_in_order/data_point_#{i}/data_point.osw", __FILE__)
  # osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

  # FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
  # expect(File.exist?(osw_out_path)).to eq false

  # if !File.exist?(osw_out_path)
  # run_options = {
  # debug: true
  # }
  # k = OpenStudio::Workflow::Run.new osw_path, run_options
  # expect(k).to be_instance_of OpenStudio::Workflow::Run
  # expect(k.run).to eq :finished
  # end

  # expect(File.exist?(osw_out_path)).to eq true

  # osw_out = nil
  # File.open(osw_out_path, 'r') do |file|
  # osw_out = JSON.parse(file.read, symbolize_names: true)
  # end

  # expect(osw_out).to be_instance_of Hash
  # expect(osw_out[:completed_status]).to eq 'Success'
  # expect(osw_out[:steps]).to be_instance_of Array
  # expect(osw_out[:steps].size).to be == 3
  # osw_out[:steps].each do |step|
  # expect(step[:arguments]).to_not be_nil

  # arguments = step[:arguments]
  # puts "arguments = #{arguments}"

  # expect(step[:result]).to_not be_nil
  # expect(step[:result][:step_values]).to_not be_nil

  # step_values = step[:result][:step_values]
  # puts "step_values = #{step_values}"

  # # check that each argument is in a value
  # skipped = false
  # arguments.each_pair do |argument_name, argument_value|
  # argument_name = argument_name.to_s
  # if argument_name == '__SKIP__'
  # skipped = argument_value
  # end
  # end

  # if skipped

  # # step_values are not populated if the measure is skipped
  # expect(step_values.size).to be == 0
  # expect(step[:result][:step_result]).to be == 'Skip'

  # else

  # arguments.each_pair do |argument_name, argument_value|
  # argument_name = argument_name.to_s
  # next if argument_name == '__SKIP__'

  # puts "argument_name = #{argument_name}"
  # puts "argument_value = #{argument_value}"
  # i = step_values.find_index { |x| x[:name] == argument_name }
  # expect(i).to_not be_nil
  # expect(step_values[i][:value]).to be == argument_value
  # end

  # expect(step[:result][:step_result]).to be == 'Success'
  # end

  # expected_results = []
  # if step[:measure_dir_name] == 'XcelEDAReportingandQAQC'
  # expected_results << 'cash_flows_capital_type'
  # expected_results << 'annual_consumption_electricity'
  # expected_results << 'annual_consumption_gas'
  # end

  # expected_results.each do |expected_result|
  # i = step_values.find_index { |x| x[:name] == expected_result }
  # expect(i).to_not be_nil
  # end
  # end
  # end
  # end

  it 'should run OSW custom output adapter' do
    osw_path = File.expand_path('../../files/run_options_osw/run_options.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    custom_start_path = File.expand_path('../../files/run_options_osw/run/custom_started.job', __dir__)
    FileUtils.rm_rf(custom_start_path) if File.exist?(custom_start_path)
    expect(File.exist?(custom_start_path)).to eq false

    custom_finished_path = File.expand_path('../../files/run_options_osw/run/custom_finished.job', __dir__)
    FileUtils.rm_rf(custom_finished_path) if File.exist?(custom_finished_path)
    expect(File.exist?(custom_finished_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    begin
      OpenStudio::RunOptions.new
      expect(File.exist?(custom_start_path)).to eq true
      expect(File.exist?(custom_finished_path)).to eq true
    rescue NameError => e
      # feature not available
    end
  end

  it 'should handle weather file throughout the run' do
    osw_path = File.expand_path('../../files/weather_file/weather_file.osw', __dir__)
    expect(File.exist?(osw_path)).to eq true

    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    workflow_json = nil
    begin
      workflow_json = OpenStudio::WorkflowJSON.new(OpenStudio::Path.new(osw_path))
    rescue NameError => e
      workflow = ::JSON.parse(File.read(osw_path), symbolize_names: true)
      workflow_json = WorkflowJSON_Shim.new(workflow, File.dirname(osw_path))
    end

    seed = workflow_json.seedFile
    expect(seed.empty?).to be false
    seed = workflow_json.findFile(seed.get)
    expect(seed.empty?).to be false

    vt = OpenStudio::OSVersion::VersionTranslator.new
    model = vt.loadModel(seed.get)
    expect(model.empty?).to be false

    weather_file = model.get.getOptionalWeatherFile
    expect(weather_file.empty?).to be false
    weather_file_path = weather_file.get.path
    expect(weather_file_path.empty?).to be false
    weather_file_path = workflow_json.findFile(weather_file_path.get.to_s)
    expect(weather_file_path.empty?).to be false
    expect(File.exist?(weather_file_path.get.to_s)).to be true
    expect(File.basename(weather_file_path.get.to_s)).to eq 'USA_CO_Golden-NREL.724666_TMY3.epw'

    weather_file_path = workflow_json.weatherFile
    expect(weather_file_path.empty?).to be false
    weather_file_path = workflow_json.findFile(weather_file_path.get.to_s)
    expect(weather_file_path.empty?).to be false
    expect(File.exist?(weather_file_path.get.to_s)).to be true
    expect(File.basename(weather_file_path.get.to_s)).to eq 'USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw'

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    # check epw in run dir

    # check sql

    # add reporting measure to check?
  end

  it 'should run null_seed OSW file' do
    osw_path = File.expand_path('../../files/null_seed/null_seed.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  it 'should run an initially empty EPW file' do
    osw_path = File.expand_path('../../files/empty_epw/empty_epw.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  it 'should fail to run an OSW with out of order steps' do
    osw_path = File.expand_path('../../files/bad_order_osw/bad_order.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :errored

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Fail'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to be_nil # cause they did not run
    end
  end

  it 'should register repeated measure results by name if the name key exists' do
    osw_path = File.expand_path('../../files/repeated_measure_osw/repeated_measure.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    out_json_path = File.expand_path('../../files/repeated_measure_osw/run/measure_attributes.json', __dir__)

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end

    expect(File.exist?(out_json_path)).to eq true

    attr_json = JSON.parse(File.read(out_json_path), symbolize_names: true)

    expect(attr_json).to be_instance_of Hash
    expect(attr_json.keys).to include(:measure_1, :measure_2)
    expect(attr_json[:measure_1].keys).to include(:r_value, :applicable)
    expect(attr_json[:measure_1][:r_value]).to eq 45
    expect(attr_json[:measure_1][:applicable]).to eq true
    expect(attr_json[:measure_2].keys).to include(:r_value, :applicable)
    expect(attr_json[:measure_2][:r_value]).to eq 45
    expect(attr_json[:measure_2][:applicable]).to eq true
  end

  it 'should test halt_workflow' do
    osw_path = File.expand_path('../../files/halt_workflow_osw/halt_workflow.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run

    res = k.run
    expect(res).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Invalid'
    expect(osw_out[:current_step]).to eq 2
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to eq 4
    expect(osw_out[:steps][0][:result]).to be_instance_of Hash
    expect(osw_out[:steps][0][:result][:step_result]).to eq 'Success'
    expect(osw_out[:steps][1][:result]).to be_instance_of Hash
    expect(osw_out[:steps][1][:result][:step_result]).to eq 'Success'
    expect(osw_out[:steps][2][:result]).to be_nil
    expect(osw_out[:steps][3][:result]).to be_nil
  end

  it 'should test script errors' do
    osw_path = File.expand_path('../../files/script_error_osw/script_error.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run

    res = k.run
    expect(res).to eq :errored

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Fail'
  end

  it 'should run fast OSW file' do
    osw_path = File.expand_path('../../files/fast_osw/fast.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    # out.osw not saved in fast mode
    expect(File.exist?(osw_out_path)).to eq false
  end

  it 'should run skip_zip_results OSW file' do
    osw_path = File.expand_path('../../files/skip_zip_results_osw/skip_zip_results.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    zip_path = File.join(File.dirname(osw_path), 'run', 'data_point.zip')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    FileUtils.rm_rf(zip_path) if File.exist?(zip_path)
    expect(File.exist?(zip_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    # out.osw saved in skip_zip_results mode
    expect(File.exist?(osw_out_path)).to eq true

    # data_point.zip not saved in skip_zip_results mode
    expect(File.exist?(zip_path)).to eq false
  end

  it 'should run reporting measures for UrbanOpt with no idf' do
    osw_path = File.join(__FILE__, './../../../files/urbanopt/data_point.osw')
    # run post process
    run_options = {
      debug: true,
      preserve_run_dir: false,
      jobs: [
        { state: :queued, next_state: :initialization, options: { initial: true } },
        { state: :initialization, next_state: :reporting_measures, job: :RunInitialization,
          file: 'openstudio/workflow/jobs/run_initialization.rb', options: {} },
        { state: :reporting_measures, next_state: :postprocess, job: :RunReportingMeasures,
          file: 'openstudio/workflow/jobs/run_reporting_measures.rb', options: {} },
        { state: :postprocess, next_state: :finished, job: :RunPostprocess,
          file: 'openstudio/workflow/jobs/run_postprocess.rb', options: {} },
        { state: :finished },
        { state: :errored }
      ]
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run reporting measures without UrbanOpt and with no idf with a fail' do
    osw_path = File.join(__FILE__, './../../../files/urbanopt/data_point_no_urbanopt.osw')
    run_dir = File.join(__FILE__, './../../../files/urbanopt/run')
    # osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    FileUtils.rm_rf(run_dir) # if File.exist?(osw_out_path)
    # expect(File.exist?(osw_out_path)).to eq false

    # run post process
    run_options = {
      debug: true,
      preserve_run_dir: false,
      jobs: [
        { state: :queued, next_state: :initialization, options: { initial: true } },
        { state: :initialization, next_state: :reporting_measures, job: :RunInitialization,
          file: 'openstudio/workflow/jobs/run_initialization.rb', options: {} },
        { state: :reporting_measures, next_state: :postprocess, job: :RunReportingMeasures,
          file: 'openstudio/workflow/jobs/run_reporting_measures.rb', options: {} },
        { state: :postprocess, next_state: :finished, job: :RunPostprocess,
          file: 'openstudio/workflow/jobs/run_postprocess.rb', options: {} },
        { state: :finished },
        { state: :errored }
      ]
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :errored
  end
end

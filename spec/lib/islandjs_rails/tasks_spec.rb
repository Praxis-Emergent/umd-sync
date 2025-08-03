require_relative '../../spec_helper'
require 'islandjs_rails/tasks'

RSpec.describe "Islandjs Rake Tasks" do
  before(:all) do
    # Create a mock environment task for testing
    unless Rake::Task.task_defined?('environment')
      Rake::Task.define_task('environment') { }
    end
    
    # Load the tasks only if they haven't been loaded yet
    unless Rake::Task.task_defined?('islandjs:init')
    load File.expand_path('../../../../lib/islandjs_rails/tasks.rb', __FILE__)
    end
  end

  before(:each) do
    # Reset invoked tasks
    Rake.application.tasks.each(&:reenable)
  end

  describe "islandjs:init" do
    it "calls IslandjsRails.init!" do
      expect(IslandjsRails).to receive(:init!)
      
      Rake.application.invoke_task("islandjs:init")
    end
  end

  describe "islandjs:install" do
    context "with package name only" do
      it "calls IslandjsRails.install! with package name" do
        expect(IslandjsRails).to receive(:install!).with("react", nil)
        
        Rake.application.invoke_task("islandjs:install[react]")
      end
    end

    context "with package name and version" do
      it "calls IslandjsRails.install! with both arguments" do
        expect(IslandjsRails).to receive(:install!).with("react", "18.3.1")
        
        Rake.application.invoke_task("islandjs:install[react,18.3.1]")
      end
    end

    context "without package name" do
      it "prints error message and exits" do
        expect do
          expect do
            Rake.application.invoke_task("islandjs:install[]")
          end.to output(/Please specify a package name/).to_stdout
        end.to raise_error(SystemExit)
      end
    end
  end

  describe "islandjs:update" do
    context "with package name only" do
      it "calls IslandjsRails.update! with package name" do
        expect(IslandjsRails).to receive(:update!).with("react", nil)
        
        Rake.application.invoke_task("islandjs:update[react]")
      end
    end

    context "with package name and version" do
      it "calls IslandjsRails.update! with both arguments" do
        expect(IslandjsRails).to receive(:update!).with("react", "18.3.1")
        
        Rake.application.invoke_task("islandjs:update[react,18.3.1]")
      end
    end

    context "without package name" do
      it "prints error message and exits" do
        expect do
          expect do
            Rake.application.invoke_task("islandjs:update[]")
          end.to output(/Please specify a package name/).to_stdout
        end.to raise_error(SystemExit)
      end
    end
  end

  describe "islandjs:remove" do
    context "with package name" do
      it "calls IslandjsRails.remove! with package name" do
        expect(IslandjsRails).to receive(:remove!).with("react")
        
        Rake.application.invoke_task("islandjs:remove[react]")
      end
    end

    context "without package name" do
      it "prints error message and exits" do
        expect do
          expect do
            Rake.application.invoke_task("islandjs:remove[]")
          end.to output(/Please specify a package name/).to_stdout
        end.to raise_error(SystemExit)
      end
    end
  end

  describe "islandjs:sync" do
    it "calls IslandjsRails.sync!" do
      expect(IslandjsRails).to receive(:sync!)
      
      Rake.application.invoke_task("islandjs:sync")
    end
  end

  describe "islandjs:status" do
    it "calls IslandjsRails.status!" do
      expect(IslandjsRails).to receive(:status!)
      
      Rake.application.invoke_task("islandjs:status")
    end
  end

  describe "islandjs:clean" do
    it "calls IslandjsRails.clean!" do
      expect(IslandjsRails).to receive(:clean!)
      
      Rake.application.invoke_task("islandjs:clean")
    end
  end

  describe "islandjs:config" do
    it "displays configuration information" do
      config = double('configuration')
      allow(IslandjsRails).to receive(:configuration).and_return(config)
      allow(config).to receive_messages(
        package_json_path: '/path/to/package.json',
        partials_dir: '/path/to/partials',
        webpack_config_path: '/path/to/webpack.config.js',
        supported_cdns: ['https://unpkg.com'],
        global_name_overrides: { 'react' => 'React' }
      )

      expect { Rake.application.invoke_task("islandjs:config") }.to output(
        a_string_including("📊 IslandjsRails Configuration")
        .and(including("Package.json path: /path/to/package.json"))
        .and(including("Partials directory: /path/to/partials"))
        .and(including("Webpack config path: /path/to/webpack.config.js"))
        .and(including("Supported CDNs: https://unpkg.com"))
        .and(including("Global name overrides: 1 configured"))
      ).to_stdout
    end
  end
end 
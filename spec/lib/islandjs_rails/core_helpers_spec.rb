require_relative '../../spec_helper'

RSpec.describe IslandjsRails::Core do
  let(:temp_dir) { Dir.mktmpdir }
  let(:core) { IslandjsRails::Core.new }

  after do
    FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
  end

  describe 'core helper methods' do
    describe '#demo_route_exists?' do
      it 'returns false when routes.rb does not exist' do
        Dir.chdir(temp_dir) do
          expect(core.demo_route_exists?).to be false
        end
      end

      it 'returns true when routes.rb contains islandjs/react' do
        routes_content = <<~RUBY
          Rails.application.routes.draw do
            get 'islandjs/react', to: 'islandjs_demo#react'
          end
        RUBY
        
        Dir.chdir(temp_dir) do
          FileUtils.mkdir_p('config')
          File.write('config/routes.rb', routes_content)
          expect(core.demo_route_exists?).to be true
        end
      end

      it 'returns true when routes.rb contains islandjs_demo' do
        routes_content = <<~RUBY
          Rails.application.routes.draw do
            get 'demo', to: 'islandjs_demo#index'
          end
        RUBY
        
        Dir.chdir(temp_dir) do
          FileUtils.mkdir_p('config')
          File.write('config/routes.rb', routes_content)
          expect(core.demo_route_exists?).to be true
        end
      end

      it 'returns false when routes.rb exists but has no demo routes' do
        routes_content = <<~RUBY
          Rails.application.routes.draw do
            root 'home#index'
          end
        RUBY
        
        Dir.chdir(temp_dir) do
          FileUtils.mkdir_p('config')
          File.write('config/routes.rb', routes_content)
          expect(core.demo_route_exists?).to be false
        end
      end
    end

    describe '#create_demo_route!' do
      it 'skips when routes.rb does not exist' do
        Dir.chdir(temp_dir) do
          expect { core.create_demo_route! }.to output(/Routes file not found/).to_stdout
        end
      end

      it 'adds route when routes.rb has proper structure' do
        routes_content = <<~RUBY
          Rails.application.routes.draw do
            root 'home#index'
          end
        RUBY
        
        Dir.chdir(temp_dir) do
          FileUtils.mkdir_p('config')
          File.write('config/routes.rb', routes_content)
          
          expect { core.create_demo_route! }.to output(/Added route to config/).to_stdout
          
          updated_content = File.read('config/routes.rb')
          expect(updated_content).to include("get 'islandjs/react', to: 'islandjs_demo#react'")
        end
      end

      it 'shows manual instruction when routes.rb has no end statement' do
        routes_content = "# Empty routes file"
        
        Dir.chdir(temp_dir) do
          FileUtils.mkdir_p('config')
          File.write('config/routes.rb', routes_content)
          
          expect { core.create_demo_route! }.to output(/Could not automatically add route/).to_stdout
        end
      end
    end
  end
end 
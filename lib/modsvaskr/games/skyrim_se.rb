require 'open-uri'
require 'tmpdir'
require 'nokogiri'

module Modsvaskr

  module Games

    # Handle a Skyrim installation
    class SkyrimSe < Game

      # Initialize the game
      # [API] - This method is optional
      def init
        @tmp_dir = "#{Dir.tmpdir}/modsvaskr"
      end

      # Complete the game menu
      # [API] - This method is optional
      #
      # Parameters::
      # * *menu* (CursesMenu): Menu to complete
      def complete_game_menu(menu)
        menu.item 'Install SKSE64' do
          install_skse64
          out 'Press Enter to continue...'
          wait_for_user_enter
        end
      end

      # Get the game running executable name (that can be found in a tasks manager)
      # [API] - This method is mandatory
      #
      # Result::
      # * String: The running exe name
      def running_exe
        'SkyrimSE.exe'
      end

      # Ordered list of default esps present in the game (the ones in the Data folder when 0 mod is being used).
      # The list is ordered according to the game's load order.
      # [API] - This method is mandatory
      #
      # Result::
      # * Array<String>: List of esp/esm/esl base file names.
      def game_esps
        %w[
          skyrim.esm
          update.esm
          dawnguard.esm
          hearthfires.esm
          dragonborn.esm
          ccbgssse001-fish.esm
          ccqdrsse001-survivalmode.esl
          ccbgssse037-curios.esl
          ccbgssse025-advdsgs.esm
        ]
      end

      # Read the load order.
      # [API] - This method is mandatory
      #
      # Result::
      # * Array<String>: List of all active plugins, including masters
      def read_load_order
        game_esps +
          File.read("#{ENV.fetch('USERPROFILE')}/AppData/Local/Skyrim Special Edition/plugins.txt").split("\n").map do |line|
            line =~ /^\*(.+)$/ ? Regexp.last_match(1).downcase : nil
          end.compact
      end

      private

      # Install SKSE64 corresponding to our game
      def install_skse64
        doc = Nokogiri::HTML(URI.open('https://skse.silverlock.org/'))
        p_element = doc.css('p').find { |el| el.text.strip =~ /^Current SE build .+: 7z archive$/ }
        if p_element.nil?
          log '!!! Can\'t get SKSE64 from https://skse.silverlock.org/. It looks like the page structure has changed. Please update the code or install it manually.'
        else
          url = "https://skse.silverlock.org/#{p_element.at('a')['href']}"
          path = "#{@tmp_dir}/skse64.7z"
          FileUtils.mkdir_p File.dirname(path)
          log "Download from #{url} => #{path}..."
          URI.parse(url).open('rb') do |web_io|
            File.write(path, web_io.read, mode: 'wb')
          end
          skse64_tmp_dir = "#{@tmp_dir}/skse64"
          log "Unzip into #{skse64_tmp_dir}..."
          FileUtils.rm_rf skse64_tmp_dir
          FileUtils.mkdir_p skse64_tmp_dir
          run_cmd(
            {
              dir: @config.seven_zip_path,
              exe: '7z.exe'
            },
            args: ['x', "\"#{path}\"", "-o\"#{skse64_tmp_dir}\"", '-r']
          )
          skse64_subdir = Dir.glob("#{skse64_tmp_dir}/*").first
          log "Move files from #{skse64_subdir} to #{self.path}..."
          FileUtils.cp_r "#{skse64_subdir}/.", self.path, remove_destination: true
          log 'SKSE64 installed successfully.'
        end
      end

    end

  end

end

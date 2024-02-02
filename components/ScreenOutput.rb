# frozen_string_literal: true

require 'lolize'
require 'whirly'
require 'paint'

# paints screen and output CLI messages
class ScreenOutput
  def initialize
    @colorizer = Lolize::Colorizer.new
  end

  def laridae_logo
    <<~ASCII




                        /(((((((
                      //((((((
                    /////(((
                ////////
      %%%%%%%%    ////////
        %%%%%%%%    ////////
          %%%%%%%%    ////////
              %%%%%%%%   ////////
            &&%%%%%%
          &&&&&%%%
        &&&&&&&%
      &&&&&&&%

       _            _     _
      | | __ _ _ __(_) __| | __ _  ___
      | |/ _` | '__| |/ _` |/ _` |/ _ \\
      | | (_| | |  | | (_| | (_| |  __\/
      |_|\\__,_|_|  |_|\\__,_|\\__,_|\\___|

    ASCII
  end

  def clear_screen
    if Gem.win_platform?
      system 'cls'
    else
      system 'clear'
    end
  end

  def run_loaders(messages)
    messages.each do |m|
      Whirly.start spinner: 'dots', color: false, status: m, stop: '✔' do
        sleep 1
      end
    end
    sleep 1
  end

  def colorize_write(message)
    @colorizer.write(message)
  end

  def show_init_message
    messages = ['Connecting to Database', 'Initializing Laridae Database',
                'Initializing Schemas', 'Creating Migration Records']
    sucessful_message = "\nInitialization successful\n\n"

    clear_screen
    colorize_write(laridae_logo)
    run_loaders(messages)
    colorize_write(sucessful_message)
  end
end

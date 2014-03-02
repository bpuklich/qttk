module Quadtone

  class Profile

    attr_accessor :name
    attr_accessor :printer
    attr_accessor :printer_options
    attr_accessor :inks
    attr_accessor :characterization_curveset
    attr_accessor :linearization_curveset
    attr_accessor :default_limit
    attr_accessor :limits
    attr_accessor :gray_highlight
    attr_accessor :gray_shadow
    attr_accessor :gray_overlap
    attr_accessor :gray_gamma
    attr_accessor :mtime

    ProfileName = 'profile'
    CharacterizationName = 'characterization'
    LinearizationName = 'linearization'
    ImportantPrinterOptions = %w{MediaType Resolution ripSpeed stpDither}
    ProfileDir = Pathname.new(ENV['HOME']) + '.qttk'

    def self.load(name)
      profile_path = ProfileDir + name
      profile = YAML::load(profile_path.open.read)
      profile.mtime = profile_path.mtime
      profile.setup
      profile
    end

    def initialize(params={})
      @mtime = Time.now
      @printer_options = {}
      @default_limit = 1
      @gray_highlight = 6
      @gray_shadow = 6
      @gray_overlap = 10
      @gray_gamma = 1
      params.each { |key, value| method("#{key}=").call(value) }
      setup
    end

    def printer=(name)
      @printer = Printer.new(name)
    end

    def profile_path
      ProfileDir + @name + "#{ProfileName}.yaml"
    end

    def characterization_ti3_path
      ProfileDir + @name + "#{CharacterizationName}.ti3"
    end

    def linearization_ti3_path
      ProfileDir + @name + "#{LinearizationName}.ti3"
    end

    def qtr_profile_path
      ProfileDir + @name + "#{@name}.txt"
    end

    def quad_file_path
      Pathname.new('/Library/Printers/QTR/quadtone') + @printer.name + "#{@name}.quad"
    end

    def setup
      raise "No printer specified" unless @printer
      ppd_options = @printer.ppd.options
      ImportantPrinterOptions.each do |option_name|
        option = ppd_options.find { |o| o[:keyword] == option_name }
        if option
          @printer_options[option[:keyword]] ||= option[:default_choice]
        else
          warn "Printer does not support option: #{option_name.inspect}"
        end
      end
      @inks ||= @printer.inks
      read_characterization_curveset!
      read_linearization_curveset!
    end

    def to_yaml_properties
      super - [:@characterization_curveset, :@linearization_curveset, :@printer]
    end

    def read_characterization_curveset!
      if characterization_ti3_path.exist?
        @characterization_curveset = CurveSet.from_ti3_file(characterization_ti3_path, Color::QTR)
      else
        warn "No characterization file: #{characterization_ti3_path}"
      end
    end

    def read_linearization_curveset!
      if linearization_ti3_path.exist?
        if characterization_ti3_path.exist? && linearization_ti3_path.mtime > characterization_ti3_path.mtime && linearization_ti3_path.mtime > @mtime
          @linearization_curveset = CurveSet.from_ti3_file(linearization_ti3_path, Color::Gray)
        else
          warn "Ignoring outdated linearization file: #{linearization_ti3_path}"
        end
      else
        warn "No linearization file: #{linearization_ti3_path}"
      end
    end

    def save!
     profile_path.open('w') { |fh| YAML::dump(self, fh) }
    end

    def initial_characterization_curveset
      CurveSet.new(color_class: Color::QTR, channels: @inks, limits: @limits)
    end

    def initial_linearization_curveset
      CurveSet.new(color_class: Color::Gray)
    end

    def build_targets
      initial_characterization_curveset.build_target(CharacterizationName)
      initial_linearization_curveset.build_target(LinearizationName)
    end

    def measure_targets(options)
      initial_characterization_curveset.measure_target(CharacterizationName) if options[:characterization]
      initial_linearization_curveset.measure_target(LinearizationName) if options[:linearization]
    end

    def qtr_profile(io)

      raise "No characterization is set" unless @characterization_curveset

      io.puts "PRINTER=#{@printer.name}"
      io.puts "GRAPH_CURVE=NO"
      io.puts

      io.puts "N_OF_INKS=#{@characterization_curveset.num_channels}"
      io.puts

      io.puts "DEFAULT_INK_LIMIT=#{@default_limit * 100}"
      @characterization_curveset.curves.each do |curve|
        io.puts "LIMIT_#{curve.key}=#{curve.limit.input * 100}"
      end
      io.puts

      io.puts "N_OF_GRAY_PARTS=#{@characterization_curveset.num_channels}"
      io.puts

      @characterization_curveset.separations.each_with_index do |separation, i|
        channel, input = *separation
        io.puts "GRAY_INK_#{i+1}=#{channel}"
        io.puts "GRAY_VAL_#{i+1}=#{input * 100}"
        io.puts
      end

      io.puts "GRAY_HIGHLIGHT=#{@gray_highlight}"
      io.puts "GRAY_SHADOW=#{@gray_shadow}"
      io.puts "GRAY_OVERLAP=#{@gray_overlap}"
      io.puts "GRAY_GAMMA=#{@gray_gamma}"
      io.puts

      if @linearization_curveset
        curve = @linearization_curveset.curves.first
        samples = curve.interpolated_samples(21)
        samples.each_with_index do |sample, i|
          raise "Linearization not monotonically increasing" if i > 0 && i < samples[i - 1]
        end
        io.puts "LINEARIZE=\"#{samples.map { |s| s.output * 100 }.join(' ')}\""
      end
    end

    def write_qtr_profile
      ;;warn "writing QTR profile to #{qtr_profile_path}"
      qtr_profile_path.open('w') { |io| qtr_profile(io) }
    end

    def install
      system('/Library/Printers/QTR/bin/quadprofile', qtr_profile_path)
    end

    def print_image(image_path, options={})
      options['ripCurve1'] = @name if options['ColorModel'] != 'QTCAL'
      options.merge!(@printer_options)
      @printer.print_file(image_path, options)
    end

    def to_html
      html = Builder::XmlMarkup.new(indent: 2)
      html.declare!(:DOCTYPE, :html)
      html.html do
        html.head do
          html.title("Profile: #{@name}")
        end
        html.body do
          html.h1("Profile: #{@name}")
          html.ul do
            html.li("Printer: #{@printer.name}")
            html.li("Printer options:")
            html.ul do
              @printer_options.each do |key, value|
                html.li("#{key}: #{value}")
              end
            end
            html.li("Inks: #{@inks.join(', ')}")
            html.li("Last modification time: #{@mtime}")
          end
          html.div do
            html.h2("Characterization curves")
            if @characterization_curveset
              html << @characterization_curveset.to_html
            else
              html.text('(Not defined)')
            end
          end
          html.div do
            html.h2("Linearization curves")
            if @linearization_curveset
              html << @linearization_curveset.to_html
            else
              html.text('(Not defined)')
            end
          end
        end
      end
      html.target!
    end

  end

end
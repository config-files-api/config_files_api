$:.unshift File.expand_path("../../lib", __FILE__)

def load_data(path)
  File.read(File.expand_path("../data/#{path}", __FILE__))
end

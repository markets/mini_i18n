module Kernel
  # Global shortcuts for MiniI18n convenience methods
  
  def T(*args)
    MiniI18n.t(*args)
  end
  
  def L(*args)
    MiniI18n.l(*args)
  end
end
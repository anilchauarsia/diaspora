class Contact

  alias_method :receive_tokens_original, :receive_tokens

  def receive_tokens(*args)
    nil
  end
end

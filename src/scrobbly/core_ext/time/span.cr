struct Time
  struct Span
    def to_json(builder)
      builder.number(total_seconds.to_i)
    end
  end
end

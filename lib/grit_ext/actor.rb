module Grit
  class Actor

    alias_method :old_name, :name
    alias_method :old_email, :email

    def name
      GritExt.encode! old_name
    end

    def email
      GritExt.encode! old_email
    end
  end
end

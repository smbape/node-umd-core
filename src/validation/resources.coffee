factory = ->
    (options)->
        {prefix, suffix} = options?.interpolation or {prefix: "{{", suffix: "}}"}

        "en-GB": translation:
            error:
                required: "Field is required"
                required_field: "Field '#{prefix}field#{suffix}' is required"
                maxLength: "Number of characters must not exceed #{prefix}maxLength#{suffix}. Given #{prefix}given#{suffix}"
                minLength: "Number of characters must be at least #{prefix}minLength#{suffix}. Given #{prefix}given#{suffix}"
                length: "Number of characters must be #{prefix}length#{suffix}. Given: #{prefix}given#{suffix}"
                either: "One of [#{prefix}list#{suffix}] is required"
                digit: "Missing a digit character"
                lowercase: "Missing a lowercase character"
                uppercase: "Missing an uppercase character"
                special: "Missing a special character"
                email: "#{prefix}attr#{suffix} is not a valid email"
        "fr-FR": translation:
            error:
                required: "Le champ est requis"
                required_field: "Le champ '#{prefix}field#{suffix}' est requis"
                maxLength: "Le nombre de charactères ne peut dépasser #{prefix}maxLength#{suffix}. Actuel: #{prefix}given#{suffix}"
                minLength: "Le nombre de charactères doit être au moins #{prefix}minLength#{suffix}. Actuel: #{prefix}given#{suffix}"
                length: "Le nombre de charactères doit être #{prefix}length#{suffix}. Actuel: #{prefix}given#{suffix}"
                either: "L'un des champs [#{prefix}list#{suffix}] est requis"
                digit: "Un chiffre est requis"
                lowercase: "Une minuscule est requise"
                uppercase: "Une majuscule est requise"
                special: "Un caractère spécial est requis"
                email: "#{prefix}attr#{suffix} n'est pas une adresse email valide"

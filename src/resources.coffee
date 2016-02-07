factory = ->
    (options)->
        {prefix, suffix} = options?.interpolation or {prefix: "{{", suffix: "}}"}

        "en-GB": translation:
            name: "English"
            welcome: "Welcome"
            default: home: index: title: "Home"
            brand: "Brand"
            "change-language": "Change language"
            button:
                create: "Create"
                edit: "Edit"
                cancel: "Cancel"
                save: "Save"
                delete: "Delete"
                login: "Sign in"
                logout: "Sign out"
        "fr-FR": translation:
            name: "Français"
            welcome: "Bienvenue"
            default: home: index: title: "Accueil"
            brand: "Marque"
            "change-language": "Changer la langue"
            button:
                create: "Créer"
                edit: "Modifier"
                cancel: "Annuler"
                save: "Enregistrer"
                delete: "Supprimer"
                login: "Se connecter"
                logout: "Se déconnecter"
Settings::DEXES_WITH_OFFSETS  = [4]

module GameData
    class Species
        def self.check_graphic_file(path, species, form = 0, gender = 0, shiny = false, shadow = false, subfolder = "")
            try_subfolder = sprintf("%s/", subfolder)
            try_species = species
            try_form    = (form > 0) ? sprintf("_%d", form) : ""
            try_gender  = (gender == 1) ? "Female/" : ""
            try_shadow  = (shadow) ? "_shadow" : ""
            factors = []
            factors.push([4, sprintf("%s shiny/", subfolder), try_subfolder]) if shiny
            factors.push([3, try_shadow, ""]) if shadow
            factors.push([2, try_gender, ""]) if gender == 1
            factors.push([1, try_form, ""]) if form > 0
            factors.push([0, try_species, "0000"])
            # Go through each combination of parameters in turn to find an existing sprite
            (2**factors.length).times do |i|
                # Set try_ parameters for this combination
                factors.each_with_index do |factor, index|
                    value = ((i / (2**index)).even?) ? factor[1] : factor[2]
                    case factor[0]
                        when 0 then try_species   = value
                        when 1 then try_form      = value
                        when 2 then try_gender    = value
                        when 3 then try_shadow    = value
                        when 4 then try_subfolder = value   # Shininess
                    end
                end
                # Look for a graphic matching this combination's parameters
                try_species_text = try_species
                ret = pbResolveBitmap(sprintf("%s%s%s%s%s%s", path, try_subfolder,
                                            try_gender, try_species_text, try_form, try_shadow))
                return ret if ret
            end
            return nil
        end
    end
end

class PokemonPokedexMenu_Scene
    def pbStartScene(commands, commands2)
        @commands = commands
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 99999
        @sprites = {}
        @sprites["background"] = IconSprite.new(0, 0, @viewport)
        @sprites["background"].setBitmap(_INTL("Graphics/UI/Pokedex/bg_menu"))
        text_tag = shadowc3tag(SEEN_OBTAINED_TEXT_BASE, SEEN_OBTAINED_TEXT_SHADOW)
        @sprites["headings"] = Window_AdvancedTextPokemon.newWithSize(
            text_tag + _INTL("VISTOS") + "  " + _INTL("OBTENIDOS") + "</c3>", 270, 136, 240, 64, @viewport
        )
        @sprites["headings"].windowskin = nil
        @sprites["commands"] = Window_DexesList.new(commands, commands2, Graphics.width - 84)
        @sprites["commands"].x      = 40
        @sprites["commands"].y      = 192
        @sprites["commands"].height = 192
        @sprites["commands"].viewport = @viewport
        pbFadeInAndShow(@sprites) { pbUpdate }
    end
end

class PokemonPokedexInfo_Scene
    def pbUpdateDummyPokemon
        @species = @dexlist[@index][:species]
        @gender, @form, _shiny = $player.pokedex.last_form_seen(@species)
        @shiny = _shiny
        metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
        @sprites["infosprite"].setSpeciesBitmap(@species, @gender, @form, @shiny)
        @sprites["formfront"]&.setSpeciesBitmap(@species, @gender, @form, @shiny)
        if @sprites["formback"]
            @sprites["formback"].setSpeciesBitmap(@species, @gender, @form, @shiny, false, true)
            @sprites["formback"].y = 256
            #@sprites["formback"].y += metrics_data.back_sprite[1] * 2
        end
        @sprites["formicon"]&.pbSetParams(@species, @gender, @form, @shiny)
    end

    def pbChooseForm
        index = 0
        @available.length.times do |i|
            if @available[i][1] == @gender && @available[i][2] == @form
                index = i
                break
            end
        end
        oldindex = -1
        old_shiny = true
        #Agregado para observar las versiones shiny
        shiny = false
        @sprites["leftarrow"] = AnimatedSprite.new("Graphics/UI/left_arrow", 8, 40, 28, 2, @viewport)
        @sprites["leftarrow"].x = 172
        @sprites["leftarrow"].y = 308
        @sprites["leftarrow"].play
        @sprites["leftarrow"].visible = false
        @sprites["rightarrow"] = AnimatedSprite.new("Graphics/UI/right_arrow", 8, 40, 28, 2, @viewport)
        @sprites["rightarrow"].x = 312
        @sprites["rightarrow"].y = 308
        @sprites["rightarrow"].play
        @sprites["rightarrow"].visible = false
        loop do
            if oldindex != index || old_shiny != shiny
                $player.pokedex.set_last_form_seen(@species, @available[index][1], @available[index][2], shiny)
                pbUpdateDummyPokemon
                drawPage(@page)
                @sprites["uparrow"].visible   = (index > 0)
                @sprites["downarrow"].visible = (index < @available.length - 1)
                @sprites["rightarrow"].visible = !shiny
                @sprites["leftarrow"].visible = shiny
                oldindex = index
                old_shiny = shiny
            end
            Graphics.update
            Input.update
            pbUpdate
            if Input.trigger?(Input::UP)
                pbPlayCursorSE
                #index = (index + @available.length - 1) % @available.length
                index = index != 0 ? index - 1 : 0
            elsif Input.trigger?(Input::DOWN)
                pbPlayCursorSE
                #index = (index + 1) % @available.length
                index = index != @available.length - 1 ? index + 1 : @available.length - 1
            elsif Input.trigger?(Input::RIGHT)
                pbPlayCursorSE
                shiny = true
            elsif Input.trigger?(Input::LEFT)
                pbPlayCursorSE
                shiny = false
            elsif Input.trigger?(Input::BACK)
                pbPlayCancelSE
                break
            elsif Input.trigger?(Input::USE)
                pbPlayDecisionSE
                break
            end
        end
        @sprites["uparrow"].visible   = false
        @sprites["downarrow"].visible = false
        @sprites["rightarrow"].visible = false
        @sprites["leftarrow"].visible = false
        $player.pokedex.set_last_form_seen(@species, 0, 0, false)
    end
end

def pbChooseFromGameDataList(game_data, default = nil)
    if !GameData.const_defined?(game_data.to_sym)
        raise _INTL("No se encuentra la clase {1} en el módulo GameData.", game_data.to_s)
    end
    game_data_module = GameData.const_get(game_data.to_sym)
    commands = []
    game_data_module.each do |data|
        name = data.real_name
        name = yield(data) if block_given?
        next if !name
        commands.push([commands.length + 1, name, data.id])
    end
    num_sort = game_data == :Species ? -1 : 1
    return pbChooseList(commands, default, nil, num_sort)
end


MenuHandlers.add(:pokemon_debug_menu, :species_and_form, {
  "name"   => _INTL("Especie/forma..."),
  "parent" => :main,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    cmd = 0
    loop do
        msg = [_INTL("Especie {1}, forma {2}.", pkmn.speciesName, pkmn.form),
                _INTL("Especie {1}, forma {2} (forzado).", pkmn.speciesName, pkmn.form)][(pkmn.forced_form.nil?) ? 0 : 1]
        cmd = screen.pbShowCommands(msg,
                                    [_INTL("Definir especie"),
                                    _INTL("Definir forma"),
                                    _INTL("Eliminar de anulados")], cmd)
        break if cmd < 0
        case cmd
            when 0   # Set species
                species = pbChooseSpeciesList(pkmn.species)
                if species && species != pkmn.species
                pkmn.species = species
                pkmn.calc_stats
                $player.pokedex.register(pkmn) if !settingUpBattle && !pkmn.egg?
                screen.pbRefreshSingle(pkmnid)
                end
            when 1   # Set form
                cmd2 = 0
                formcmds = [[], []]
                GameData::Species.each do |sp|
                    next if sp.species != pkmn.species
                    form_name = sp.form_name
                    form_name = _INTL("Forma sin nombre") if !form_name || form_name.empty?
                    form_name = sprintf("%d: %s", sp.form, form_name)
                    formcmds[0].push(sp.form)
                    formcmds[1].push(form_name)
                    cmd2 = formcmds[0].length - 1 if pkmn.form == sp.form
                end
                paired = formcmds[0].zip(formcmds[1])
                paired.sort_by! { |x| x[0] }
                formcmds[0], formcmds[1] = paired.transpose
                if formcmds[0].length <= 1
                    screen.pbDisplay(_INTL("La especie {1} solo tiene una forma.", pkmn.speciesName))
                    if pkmn.form != 0 && screen.pbConfirm(_INTL("¿Quieres reiniciar la forma a la 0?"))
                        pkmn.form = 0
                        $player.pokedex.register(pkmn) if !settingUpBattle && !pkmn.egg?
                        screen.pbRefreshSingle(pkmnid)
                    end
                else
                cmd2 = screen.pbShowCommands(_INTL("Define la forma del Pokémon."), formcmds[1], cmd2)
                next if cmd2 < 0
                f = formcmds[0][cmd2]
                if f != pkmn.form
                    if MultipleForms.hasFunction?(pkmn, "getForm")
                        next if !screen.pbConfirm(_INTL("Esta especie decide su propia forma. ¿Sobreescribir?"))
                        pkmn.forced_form = f
                    end
                    pkmn.form = f
                    $player.pokedex.register(pkmn) if !settingUpBattle && !pkmn.egg?
                    screen.pbRefreshSingle(pkmnid)
                end
                end
            when 2   # Remove form override
                pkmn.forced_form = nil
                screen.pbRefreshSingle(pkmnid)
        end
    end
    next false
  }
})

class PokemonPokedexInfo_Scene
    def pbScene
        Pokemon.play_cry(@species, @form)
        loop do
            Graphics.update
            Input.update
            pbUpdate
            dorefresh = false
            if Input.trigger?(Input::ACTION)
                pbSEStop
                Pokemon.play_cry(@species, @form) if @page == 1
            elsif Input.trigger?(Input::BACK)
                pbPlayCloseMenuSE
                break
            elsif Input.trigger?(Input::USE)
                ret = pbPageCustomUse(@page_id)
                if !ret
                    case @page_id
                        when :page_info
                            pbPlayDecisionSE
                            @show_battled_count = !@show_battled_count
                            dorefresh = true
                        when :page_forms
                            #if @available.length > 1
                                pbPlayDecisionSE
                                pbChooseForm
                                dorefresh = true
                            #end
                        end
                    else
                    dorefresh = true
                end
            elsif Input.repeat?(Input::UP)
                oldindex = @index
                pbGoToPrevious
                if @index != oldindex
                    pbUpdateDummyPokemon
                    @available = pbGetAvailableForms
                    pbSEStop
                    (@page == 1) ? Pokemon.play_cry(@species, @form) : pbPlayCursorSE
                    dorefresh = true
                end
            elsif Input.repeat?(Input::DOWN)
                oldindex = @index
                pbGoToNext
                if @index != oldindex
                    pbUpdateDummyPokemon
                    @available = pbGetAvailableForms
                    pbSEStop
                    (@page == 1) ? Pokemon.play_cry(@species, @form) : pbPlayCursorSE
                    dorefresh = true
                end
            elsif Input.repeat?(Input::LEFT)
                oldpage = @page
                numpages = @page_list.length
                @page -= 1
                @page = numpages if @page < 1
                @page = 1 if @page > numpages 
                if @page != oldpage
                    pbPlayCursorSE
                    dorefresh = true
                end
            elsif Input.repeat?(Input::RIGHT)
                oldpage = @page
                numpages = @page_list.length
                @page += 1
                @page = numpages if @page < 1
                @page = 1 if @page > numpages
                if @page != oldpage
                    pbPlayCursorSE
                    dorefresh = true
                end
            end
            drawPage(@page) if dorefresh
        end
        return @index
  end
end
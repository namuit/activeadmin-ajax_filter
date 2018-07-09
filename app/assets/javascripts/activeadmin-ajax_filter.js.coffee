$ ->
  apply_filter_ajax_select = () ->
    $('.filter_ajax_select select, .ajax_select select').each (_, select) ->
      select = $(select)
      valueField = select.data('value-field')
      searchFields = select.data('search-fields').split(' ')
      staticRansack = select.data('static-ransack')

      ajaxFields = select.data('ajax-search-fields')
      if ajaxFields
        ajaxFields = ajaxFields.split(' ')
      else
        ajaxFields = []

      ordering = select.data('ordering')
      url = select.data('url')

      loadOptions = (q, callback) ->
        $.ajax
          url: url
          type: 'GET'
          dataType: 'json'
          data:
            q: q
            limit: select.data('limit')
            order: ordering
          error: ->
            callback()
          success: (res) ->
            callback(res)

      relatedInput = (field) ->

        possibileInputs =
          "[name*=#{field}]": select.closest('fieldset'),
          "[name*=#{field.replace('_id', '')}]": select.closest('fieldset'),
          "[id=#{field}]": select.parents('form'),

        for k, v of possibileInputs
          tmpRelatedInput = $(k, v)
          if tmpRelatedInput.length > 0
            break
        return tmpRelatedInput

      isCircularAjaxSearchLink = (initial_input_id, field) ->
        input = relatedInput(field)
        if input.length
          (input.data('ajax-search-fields') or '').split(' ').some (ajaxField) ->
            ajaxField.length > 0 && relatedInput(ajaxField).attr('id') == initial_input_id

      select.selectize
        valueField: valueField
        labelField: searchFields[0]
        searchField: searchFields
        sortField: ordering.split(',').map (clause)->
          c = clause.trim().split(' ')
          { field: c[0], direction: c[1] }
        options: []
        create: false
        preload: 'focus'
        render:
          option: (item, escape) ->
            html = searchFields.map (field, index)->
              value = escape(item[field])

              if index == 0
                klass = 'primary'
              else
                klass = 'secondary'

              "<span class='#{klass}'>#{value}</span>"
            "<div class='item'>#{html.join('')}</div>"

        load: (query, callback) ->
          q = {}
          q[select.data('ransack')] = if query.length then query else null
          for ransack, value of staticRansack
            q[ransack] = value

          ajaxFields.forEach (field) ->
            q["#{field}_eq"] = relatedInput(field).val()
            # clear cache because it wrong with changing values of ajaxFields
            select.loadedSearches = {}
          loadOptions(q, callback)

        onInitialize: ->
          selectize = this
          selectedValue = select.data('selected-value')
          selectedRansack = "#{valueField}_eq"
          # sometimes the sifter options contains other values
          this.options = this.sifter.items = {}

          prepopulateSelectedValue = ->
            if selectedValue
              q = {}
              q[selectedRansack] = selectedValue

              for ransack, value of staticRansack
                q[ransack] = value

              ajaxFields.forEach (field) ->
                q["#{field}_eq"] = relatedInput(field).val()
                select.loadedSearches = {}

              loadOptions q, (res) ->
                if res && res.length
                  selectize.addOption(res[0])
                  selectize.addItem(res[0][valueField])

          prepopulateSelectedValue()

          ajaxFields.forEach (field) ->
            if !isCircularAjaxSearchLink(selectize.$input.attr('id'), field)
              relatedInput(field).change ->
                selectize.clearOptions()
                prepopulateSelectedValue() if select.data('reload-when-search-fields-change')


  # apply ajax filter to all static inputs
  apply_filter_ajax_select()

  # apply ajax filter on inputs inside has_many entries
  $("form.formtastic .has_many_add").click ->
    setTimeout((-> apply_filter_ajax_select()), 0)

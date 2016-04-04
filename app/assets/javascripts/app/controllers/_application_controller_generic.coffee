class App.ControllerGenericNew extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: true
  headPrefix: 'New'

  content: =>
    @head = @pageData.object
    @controller = new App.ControllerForm(
      model:     App[ @genericObject ]
      params:    @item
      screen:    @screen || 'edit'
      autofocus: true
    )
    @controller.form

  onSubmit: (e) ->
    params = @formParam(e.target)

    object = new App[ @genericObject ]
    object.load(params)

    # validate
    errors = object.validate()
    if errors
      @log 'error', errors
      @formValidate( form: e.target, errors: errors )
      return false

    # disable form
    @formDisable(e)

    # save object
    ui = @
    object.save(
      done: ->
        if ui.callback
          item = App[ ui.genericObject ].fullLocal(@id)
          ui.callback(item)
        ui.close()

      fail: (settings, details) ->
        ui.log 'errors', details
        ui.formEnable(e)
        ui.controller.showAlert(details.error_human || details.error || 'Unable to create object!')
    )

class App.ControllerGenericEdit extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: true
  headPrefix: 'Edit'

  content: =>
    @item = App[ @genericObject ].find( @id )
    @head = @pageData.object

    @controller = new App.ControllerForm(
      model:      App[ @genericObject ]
      params:     @item
      screen:     @screen || 'edit'
      autofocus:  true
    )
    @controller.form

  onSubmit: (e) ->
    params = @formParam(e.target)
    @item.load(params)

    # validate
    errors = @item.validate()
    if errors
      @log 'error', errors
      @formValidate( form: e.target, errors: errors )
      return false

    # disable form
    @formDisable(e)

    # save object
    ui = @
    @item.save(
      done: ->
        if ui.callback
          item = App[ ui.genericObject ].fullLocal(@id)
          ui.callback(item)
        ui.close()

      fail: (settings, details) ->
        ui.log 'errors'
        ui.formEnable(e)
        ui.controller.showAlert(details.error_human || details.error || 'Unable to update object!')
    )

class App.ControllerGenericIndex extends App.Controller
  events:
    'click [data-type=edit]': 'edit'
    'click [data-type=new]':  'new'
    'click .js-description':  'description'

  constructor: ->
    super

    # set title
    @title @pageData.title, true

    # set nav bar
    if @pageData.navupdate
      @navupdate @pageData.navupdate

    # bind render after a change is done
    if !@disableRender
      @subscribeId = App[ @genericObject ].subscribe(@render)

    App[ @genericObject ].bind 'ajaxError', (rec, msg) =>
      @log 'error', 'ajax', msg.status
      if msg.status is 401
        @log 'error', 'ajax', rec, msg, msg.status
        @navigate 'login'

    # execute fetch
    @render()

    # fetch all
    if !@disableInitFetch
      App[ @genericObject ].fetchFull(
        ->
        clear: true
      )

  release: =>
    if @subscribeId
      App[ @genericObject ].unsubscribe(@subscribeId)

  render: =>

    objects = App[@genericObject].search(
      sortBy: @defaultSortBy || 'name'
      order:  @defaultOrder
    )

    # remove ignored items from collection
    if @ignoreObjectIDs
      objects = _.filter( objects, (item) ->
        return if item.id is 1
        return item
      )

    # show description button, only if content exists
    showDescription = false
    if App[ @genericObject ].description && !_.isEmpty(objects)
      showDescription = true

    @html App.view('generic/admin/index')(
      head:            @pageData.objects
      notes:           @pageData.notes
      buttons:         @pageData.buttons
      menus:           @pageData.menus
      showDescription: showDescription
    )

    # show description in content if no no content exists
    if _.isEmpty(objects) && App[ @genericObject ].description
      description = marked(App[ @genericObject ].description)
      @$('.table-overview').html(description)
      return

    # append content table
    params = _.extend(
      {
        el:         @$('.table-overview')
        model:      App[ @genericObject ]
        objects:    objects
        bindRow:
          events:
            'click': @edit
        container: @container
        explanation: @pageData.explanation or 'none'
        groupBy: @groupBy
        dndCallback: @dndCallback
      },
      @pageData.tableExtend
    )
    new App.ControllerTable(params)

  edit: (id, e) =>
    e.preventDefault()
    item = App[ @genericObject ].find(id)

    if @editCallback
      @editCallback(item)
      return

    new App.ControllerGenericEdit(
      id:            item.id
      pageData:      @pageData
      genericObject: @genericObject
      container:     @container
      large:         @large
    )

  new: (e) ->
    e.preventDefault()
    new App.ControllerGenericNew(
      pageData:      @pageData
      genericObject: @genericObject
      container:     @container
      large:         @large
    )

  description: (e) =>
    new App.ControllerGenericDescription(
      description: App[ @genericObject ].description
      container:   @container
    )

class App.ControllerGenericDescription extends App.ControllerModal
  buttonClose: true
  buttonCancel: false
  buttonSubmit: 'Close'
  head: 'Description'

  content: =>
    marked(@description)

  onSubmit: =>
    @close()

class App.ControllerModalLoading extends App.Controller
  className: 'modal fade'

  constructor: ->
    super

    if @container
      @el.addClass('modal--local')

    @render()

    @el.modal
      keyboard:  false
      show:      true
      backdrop:  'static'
      container: @container

  render: ->
    @html App.view('generic/modal_loader')(
      head: @head
      message: App.i18n.translateContent(@message)
    )

  update: (message, translate = true) =>
    if translate
      message = App.i18n.translateContent(message)
    @$('.js-loading').html(message)

  hideIcon: =>
    @$('.js-loadingIcon').addClass('hide')

  showIcon: =>
    @$('.js-loadingIcon').removeClass('hide')

  hide: (delay) =>
    remove = =>
      @el.remove()
    if !delay
      remove()
      return
    App.Delay.set(remove, delay * 1000)

class App.ControllerGenericDestroyConfirm extends App.ControllerModal
  buttonClose: true
  buttonCancel: true
  buttonSubmit: 'yes'
  buttonClass: 'btn--danger'
  head: 'Confirm'
  small: true

  content: ->
    App.i18n.translateContent('Sure to delete this object?')

  onSubmit: =>
    @item.destroy(
      done: =>
        @close()
        if @callback
          @callback()
      fail: =>
        @log 'errors'
        @close()
    )

class App.ControllerDrox extends App.Controller
  constructor: (params) ->
    super

    if params.data && ( params.data.text || params.data.html )
      @inline(params.data)

  inline: (data) ->
    @html App.view('generic/drox')(data)
    if data.text
      @$('.drox-body').text(data.text)
    if data.html
      @$('.drox-body').html(data.html)

  template: (data) ->
    drox = $( App.view('generic/drox')(data) )
    content = App.view(data.file)(data.params)
    drox.find('.drox-body').append(content)
    drox

class App.ControllerTabs extends App.Controller
  events:
    'click .nav-tabs [data-toggle="tab"]': 'tabRemember',

  constructor: ->
    super

  render: ->
    @html App.view('generic/tabs')(
      header: @header
      subHeader: @subHeader
      tabs: @tabs
      addTab: @addTab
    )

    # insert content
    for tab in @tabs
      @$('.tab-content').append("<div class=\"tab-pane\" id=\"#{tab.target}\"></div>")
      if tab.controller
        params = tab.params || {}
        params.name = tab.name
        params.target = tab.target
        params.el = @$( "##{tab.target}" )
        new tab.controller( params )

    # check if tabs need to be show / cant' use .tab(), because tabs are note shown (only one tab exists)
    if @tabs.length <= 1
      @$('.tab-pane').addClass('active')
      return

    # set last or first tab to active
    @lastActiveTab = @Config.get('lastTab')
    if @lastActiveTab &&  @$(".nav-tabs li a[href='#{@lastActiveTab}']")[0]
      @$(".nav-tabs li a[href='#{@lastActiveTab}']").tab('show')
    else
      @$('.nav-tabs li:first a').tab('show')

  tabRemember: (e) =>
    @lastActiveTab = $(e.target).attr('href')
    @Config.set('lastTab', @lastActiveTab)

class App.ControllerNavSidbar extends App.ControllerContent
  constructor: (params) ->
    super

    if @authenticateRequired
      return if !@authenticate()

    @params = params

    # get accessable groups
    roles = App.Session.get('roles')
    groups = App.Config.get(@configKey)
    groupsUnsorted = []
    for key, item of groups
      if !item.controller
        if !item.role
          groupsUnsorted.push item
        else
          match = _.include(item.role, 'Anybody')
          if !match
            for role in roles
              if !match
                match = _.include(item.role, role.name)
          if match
            groupsUnsorted.push item

    @groupsSorted = _.sortBy(groupsUnsorted, (item) -> return item.prio)

    # get items of group
    for group in @groupsSorted
      items = App.Config.get(@configKey)
      itemsUnsorted = []
      for key, item of items
        if item.parent is group.target
          if item.controller
            if !item.role
              itemsUnsorted.push item
            else
              match = _.include(item.role, 'Anybody')
              if !match
                for role in roles
                  if !match
                    match = _.include(item.role, role.name)
              if match
                itemsUnsorted.push item

      group.items = _.sortBy(itemsUnsorted, (item) -> return item.prio)

    # check last selected item
    selectedItem = undefined
    selectedItemMeta = App.Config.get("Runtime::#{@configKey}")
    keepLastMenuFor = 1000 * 60 * 10
    if selectedItemMeta && selectedItemMeta.date && new Date < new Date( selectedItemMeta.date.getTime() + keepLastMenuFor )
      selectedItem = selectedItemMeta.selectedItem

    # set active item
    for group in @groupsSorted
      if group.items
        for item in group.items
          if !@target && !selectedItem
            item.active = true
            selectedItem = item
          else if @target && item.target is window.location.hash
            item.active = true
            selectedItem = item
          else if @target && window.location.hash.match(item.target)
            item.active = true
            selectedItem = item
          else
            item.active = false

    @renderContainer(selectedItem)
    @renderNavBar(selectedItem)

    @bind(
      'ui:rerender'
      =>
        @renderNavBar(selectedItem)
    )

  renderContainer: =>
    return if $( ".#{@configKey}" )[0]
    @html App.view('generic/navbar_level2/index')(
      className: @configKey
    )

  renderNavBar: (selectedItem) =>

    # remember latest selected item
    selectedItemMeta =
      selectedItem: selectedItem
      date: new Date
    App.Config.set("Runtime::#{@configKey}", selectedItemMeta)

    @$('.sidebar').html App.view('generic/navbar_level2/navbar')(
      groups:     @groupsSorted
      className:  @configKey
    )
    if selectedItem
      @$('li').removeClass('active')
      @$("a[href=\"#{selectedItem.target}\"]").parent().addClass('active')
      @executeController(selectedItem)

  executeController: (selectedItem) =>

    # in case of rerendering
    if @activeController && @activeController.render
      @activeController.render()
      return

    @params.el = @$('.main')
    @activeController = new selectedItem.controller(@params)

class App.GenericHistory extends App.ControllerModal
  buttonClose: true
  buttonCancel: false
  buttonSubmit: false
  head: 'History'
  shown: false

  constructor: ->
    super
    @fetch()

  content: =>
    localItem = @reworkItems(@items)

    content = $ App.view('generic/history')(
      items: localItem
    )
    content.find('a[data-type="sortorder"]').bind('click', (e) =>
      e.preventDefault()
      @sortorder()
    )
    content

  onShown: =>
    @userPopups()

  sortorder: =>
    @items = @items.reverse()
    @update()

  T: (name) ->
    App.i18n.translateInline(name)

  reworkItems: (items) ->
    newItems = []
    newItem = {}
    lastUserId = undefined
    lastTime   = undefined
    items = clone(items)
    for item in items

      if item.object is 'Ticket::Article'
        item.object = 'Article'

      data = item
      data.created_by = App.User.find( item.created_by_id )

      currentItemTime = new Date( item.created_at )
      lastItemTime    = new Date( new Date( lastTime ).getTime() + (15 * 1000) )

      # start new section if user or time has changed
      if lastUserId isnt item.created_by_id || currentItemTime > lastItemTime
        lastTime   = item.created_at
        lastUserId = item.created_by_id
        if !_.isEmpty(newItem)
          newItems.push newItem
        newItem =
          created_at: item.created_at
          created_by: App.User.find( item.created_by_id )
          records: []

      # build content
      content = ''
      if item.type is 'notification' || item.type is 'email'
        content = "#{ @T( item.type ) } #{ @T( 'sent to' ) } '#{ item.value_to }'"
      else
        content = "#{ @T( item.type ) } #{ @T(item.object) } "
        if item.attribute
          content += "#{ @T(item.attribute) }"

          # convert time stamps
          if item.object is 'User' && item.attribute is 'last_login'
            if item.value_from
              item.value_from = App.i18n.translateTimestamp( item.value_from )
            if item.value_to
              item.value_to = App.i18n.translateTimestamp( item.value_to )

        if item.value_from
          if item.value_to
            content += " #{ @T( 'from' ) }"
          content += " '#{ App.Utils.htmlEscape(item.value_from) }'"

        if item.value_to
          if item.value_from
            content += " #{ @T( 'to' ) }"
          content += " '#{ App.Utils.htmlEscape(item.value_to) }'"

      newItem.records.push content

    if !_.isEmpty(newItem)
      newItems.push newItem

    newItems

class App.ActionRow extends App.Controller
  constructor: ->
    super
    @render()

  render: ->
    @html App.view('generic/actions')(
      items: @items
      type:  @type
    )

    for item in @items
      do (item) =>
        @$('[data-type="' + item.name + '"]').on(
          'click',
          (e) ->
            e.preventDefault()
            item.callback()
        )

class App.Sidebar extends App.Controller
  elements:
    '.tabsSidebar-tab': 'tabs'
    '.sidebar':         'sidebars'

  events:
    'click .tabsSidebar-tab':   'toggleTab'
    'click .tabsSidebar-close': 'toggleSidebar'
    'click .sidebar-header .js-headline': 'toggleDropdown'

  constructor: ->
    super
    @render()

    # get active tab by name
    if @name
      name = @name

    # get active tab last state
    if !name && @sidebarState
      name = @sidebarState.active

    # get active tab by first tab
    if !name
      name = @tabs.first().data('tab')

    # activate first tab
    @toggleTabAction(name)

  render: =>
    @html App.view('generic/sidebar_tabs')
      items: @items
      scrollbarWidth: App.Utils.getScrollBarWidth()

    # init content callback
    for item in @items
      if item.callback
        item.callback( @$( '.sidebar[data-tab="' + item.name + '"] .sidebar-content' ) )

    # add item acctions
    for item in @items
      if item.actions
        new App.ActionRow(
          el:    @$('.sidebar[data-tab="' + item.name + '"] .js-actions')
          items: item.actions
          type:  'small'
        )

  toggleDropdown: (e) ->
    e.stopPropagation()
    $(e.currentTarget).next('.js-actions').find('.dropdown-toggle').dropdown('toggle')

  toggleSidebar: =>
    @el.parent().find('.tabsSidebar-sidebarSpacer').toggleClass('is-closed')
    @el.parent().find('.tabsSidebar').toggleClass('is-closed')
    #@el.parent().next('.attributeBar').toggleClass('is-closed')

  showSidebar: ->
    @el.parent().find('.tabsSidebar-sidebarSpacer').removeClass('is-closed')
    @el.parent().find('.tabsSidebar').removeClass('is-closed')
    #@el.parent().next('.attributeBar').addClass('is-closed')

  toggleTab: (e) =>

    # get selected tab
    name = $(e.target).closest('.tabsSidebar-tab').data('tab')

    if name

      # if current tab is selected again, toggle side bar
      if name is @currentTab
        @toggleSidebar()

      # toggle content tab
      else
        @toggleTabAction(name)

  toggleTabAction: (name) ->
    return if !name

    # remember sidebarState for outsite
    if @sidebarState
      @sidebarState.active = name

    # remove active state
    @tabs.removeClass('active')

    # add active state
    @$('.tabsSidebar-tab[data-tab=' + name + ']').addClass('active')

    # hide all content tabs
    @sidebars.addClass('hide')

    # show active tab content
    tabContent = @$('.sidebar[data-tab=' + name + ']')
    tabContent.removeClass('hide')

    # remember current tab
    @currentTab = name

    # show sidebar if not shown
    @showSidebar()

class App.WizardModal extends App.Controller
  className: 'modal fade'

  constructor: ->
    super

    # rerender view, e. g. on langauge change
    @bind('ui:rerender', =>
      @render()
      'wizard'
    )

  goToSlide: (e) =>
    e.preventDefault()
    slide = $(e.target).data('slide')
    return if !slide
    @showSlide(slide)

  showSlide: (name) =>
    @hideAlert(name)
    @$('.setup.wizard').addClass('hide')
    @$(".setup.wizard.#{name}").removeClass('hide')
    @$(".setup.wizard.#{name} input, .setup.wizard.#{name} select").first().focus()

  showAlert: (screen, message) =>
    @$(".#{screen}").find('.alert').first().removeClass('hide').text(App.i18n.translatePlain(message))

  hideAlert: (screen) =>
    @$(".#{screen}").find('.alert').first().addClass('hide')

  disable: (e) =>
    @formDisable(e)
    @$('.wizard-controls .btn').attr('disabled', true)

  enable: (e) =>
    @formEnable(e)
    @$('.wizard-controls .btn').attr('disabled', false)

  hide: (e) =>
    e.preventDefault()
    @el.modal('hide')

  showInvalidField: (screen, fields) =>
    @$(".#{screen}").find('.form-group').removeClass('has-error')
    return if !fields
    for field, type of fields
      if type
        @$(".#{screen}").find("[name=\"options::#{field}\"]").closest('.form-group').addClass('has-error')

  render: ->
    # do nothing

class App.WizardFullScreen extends App.WizardModal
  className: 'getstarted fit'

  constructor: ->
    super
    $('.content').addClass('hide')
    $('#content').removeClass('hide')

class App.CollectionController extends App.Controller
  events:
    'click .js-remove': 'remove'
    'click .js-item': 'click'
    'click .js-locationVerify': 'location'
  observe:
    field1: true
    field2: false
  #currentItems: {}
    #1:
    # a: 123
    # b: 'some string'
    #2:
    # a: 123
    # b: 'some string'
  #renderList: {}
    #1: ..dom..ref..
    #2: ..dom..ref..
  template: '_need_to_be_defined_'
  uniqKey: 'id'
  model: '_need_to_be_defined_'
  sortBy: 'name'
  order: 'ASC',

  constructor: ->
    @events = @constructor.events unless @events
    @observe = @constructor.observe unless @observe
    @currentItems = {}
    @renderList = {}
    @queue = []
    @queueRunning = false
    @lastOrder = []

    super

    @queue.push ['renderAll']
    @uIRunner()

    # bind to changes
    if @model
      @subscribeId = App[@model].subscribe(@collectionSync)

    # render on generic ui call
    @bind('ui:rerender', =>
      @queue.push ['renderAll']
      @uIRunner()
    )

    # render on login
    @bind('auth:login', =>
      @queue.push ['renderAll']
      @uIRunner()
    )

    # reset current tasks on logout
    @bind('auth:logout', =>
      @queue.push ['renderAll']
      @uIRunner()
    )

    @log 'debug', 'Init @uniqKey', @uniqKey
    @log 'debug', 'Init @observe', @observe
    @log 'debug', 'Init @model', @model

  release: =>
    if @subscribeId
      App[@model].unsubscribe(@subscribeId)

  uIRunner: ->
    return if !@queue[0]
    return if @queueRunning
    @queueRunning = true
    loop
      param = @queue.shift()
      if param[0] is 'domChange'
        @domChange(param[1])
      else if param[0] is 'domRemove'
        @domRemove(param[1])
      else if param[0] is 'renderAll'
        @renderAll()
      if !@queue[0]
        @onRenderEnd()
        @queueRunning = false
        break

  collectionOrderGet: =>
    newOrder = []
    all = @itemsAll()
    for item in all
      newOrder.push item[@uniqKey]
    newOrder

  collectionOrderSet: (newOrder = false) =>
    if !newOrder
      newOrder = @collectionOrderGet()
    @lastOrder = newOrder

  collectionSync: (items, type) =>
    console.log('collectionSync', items, type)

    # remove items
    if type is 'destroy'
      ids = []
      for item in items
        ids.push item.id
      @queue.push ['domRemove', ids]
      @uIRunner()
      return

    # inital render
    if _.isEmpty(@renderList)
      @queue.push ['renderAll']
      @uIRunner()
      return

    # check if item order is the same
    newOrder = @collectionOrderGet()
    removedIds = _.difference(@lastOrder, newOrder)
    addedIds = _.difference(newOrder, @lastOrder)

    @log 'debug', 'collectionSync removedIds', removedIds
    @log 'debug', 'collectionSync addedIds', addedIds
    @log 'debug', 'collectionSync @lastOrder', @lastOrder
    @log 'debug', 'collectionSync newOrder', newOrder

    # add items
    alreadyRemoved = false
    if !_.isEmpty(addedIds)
      lastOrderNew = []
      for id in @lastOrder
        if !_.contains(removedIds, id)
          lastOrderNew.push id

      # try to find positions of new items
      applyOrder = App.Utils.diffPositionAdd(lastOrderNew, newOrder)
      if !applyOrder
        @queue.push ['renderAll']
        @uIRunner()
        return

      if !_.isEmpty(removedIds)
        alreadyRemoved = true
        @queue.push ['domRemove', removedIds]
        @uIRunner()

      newItems = []
      for apply in applyOrder
        item = App[@model].find(apply.id)
        item.meta_position = apply.position
        newItems.push item
      @queue.push ['domChange', newItems]
      @uIRunner()

    # remove items
    if !alreadyRemoved && !_.isEmpty(removedIds)
      @queue.push ['domRemove', removedIds]
      @uIRunner()

    # update items
    newItems = []
    for item in items
      if !_.contains(removedIds, item.id) && !_.contains(addedIds, item.id)
        newItems.push item
    return if _.isEmpty(newItems)
    @queue.push ['domChange', newItems]
    @uIRunner()
    #return

    # rerender all items
    #@queue.push ['renderAll']
    #@uIRunner()

  domRemove: (ids) =>
    @log 'debug', 'domRemove', ids
    for id in ids
      @itemAttributesDelete(id)
      if @renderList[id]
        @renderList[id].remove()
        delete @renderList[id]
      @onRemoved(id)
    @collectionOrderSet()

  domChange: (items) =>
    @log 'debug', 'domChange items', items
    @log 'debug', 'domChange @currentItems', @currentItems
    changedItems = []
    for item in items
      @log 'debug', 'domChange|item', item
      attributes = @itemAttributes(item)
      currentItem = @itemAttributesGet(item[@uniqKey])
      if !currentItem
        @log 'debug', 'domChange|add', item
        changedItems.push item
        @itemAttributesSet(item[@uniqKey], attributes)
      else
        @log 'debug', 'domChange|change', item
        @log 'debug', 'domChange|change|observe attributes', @observe
        @log 'debug', 'domChange|change|current', currentItem
        @log 'debug', 'domChange|change|new', attributes
        for field of @observe
          @log 'debug', 'domChange|change|compare', field, currentItem[field], attributes[field]
          diff = !_.isEqual(currentItem[field], attributes[field])
          @log 'debug', 'domChange|diff', diff, item
          if diff
            changedItems.push item
            @itemAttributesSet(item[@uniqKey], attributes)
            break
    return if _.isEmpty(changedItems)
    @renderParts(changedItems)

  renderAll: =>
    items = @itemsAll()
    @log 'debug', 'renderAll', items
    localeEls = []
    for item in items
      attributes = @itemAttributes(item)
      @itemAttributesSet(item[@uniqKey], attributes)
      localeEls.push @renderItem(item, false)
    @html localeEls
    @collectionOrderSet()
    @onRenderEnd()

  itemsAll: =>
    #App[@model].all()
    App[@model].search(sortBy: @sortBy, order: @order)

  itemAttributesDiff: (item) =>
    attributes = @itemAttributes(item)
    currentItem = @itemAttributesGet(item[@uniqKey])
    for field of @observe
      @log 'debug', 'itemAttributesDiff|compare', field, currentItem[field], attributes[field]
      diff = !_.isEqual(currentItem[field], attributes[field])
      if diff
        @log 'debug', 'itemAttributesDiff|diff', diff
        return true
    false

  itemAttributesDelete: (id) =>
    delete @currentItems[id]

  itemAttributesGet: (id) =>
    @currentItems[id]

  itemAttributesSet: (id, attributes) =>
    @currentItems[id] = attributes

  itemAttributes: (item) =>
    attributes = {}
    for field of @observe
      attributes[field] = item[field]
    attributes

  renderParts: (items) =>
    @log 'debug', 'renderParts', items
    for item in items
      if !@renderList[item[@uniqKey]]
        @renderItem(item)
      else
        @renderItem(item, @renderList[item[@uniqKey]])
    @collectionOrderSet()

  renderItem: (item, el) =>
    if @prepareForObjectListItemSupport
      item = @prepareForObjectListItem(item)
    @log 'debug', 'renderItem', item, @template, el, @renderList[item[@uniqKey]]
    html =  $(App.view(@template)(
      item: item
    ))
    @renderList[item[@uniqKey]] = html
    if el is false
      return html
    else if !el
      position = item.meta_position + 1
      console.log('!el', item, position, item.meta_position)
      #if item.meta_position
      @el.find(".js-item:nth-child(#{position})").before(html)
    else
      el.replaceWith(html)

  onRenderEnd: ->
    # nothing

  location: (e) ->
    @locationVerify(e)

  click: (e) =>
    row = $(e.target).closest('.js-item')
    id = row.data('id')
    console.log('click id', id)
    @onClick(id, e)

  onClick: (id, e) ->
    # nothing

  remove: (e) =>
    e.preventDefault()
    e.stopPropagation()
    row = $(e.target).closest('.js-item')
    id = row.data('id')
    @onRemove(id,e)
    App[@model].destroy(id)

  onRemove: (id, e) ->
    # nothing

  onRemoved: (id) ->
    # nothing


module.exports=
  class OutputViewElement

    constructor: (name, content) ->
      itemWrapper = document.createElement 'li'
      itemWrapper.classList.add 'list-nested-item', 'collapsed'

      console.log content

      item = document.createElement if content.length > 0 then 'div' else 'li'
      item.classList.add 'list-item'

      itemText = document.createElement 'span'
      itemText.classList.add 'icon', 'inline-block', 'output-element-wrapper'

      if content.length > 0
        itemText.classList.add 'icon-eye'

        identifier = document.createElement 'span'
        identifier.innerHTML = "#{name}"

        cnt = document.createElement 'span'
        cnt.classList.add 'itshape', 'subtle', 'align-right'
        cnt.innerHTML = "(cnt: #{content.length})"

        itemText.appendChild identifier
        itemText.appendChild cnt

      else
        itemText.classList.add 'icon-circle-slash', 'subtle'
        itemText.innerHTML = "#{name}"

      item.appendChild itemText

      sublist = document.createElement 'ul'
      sublist.classList.add 'list-tree', 'has-flat-children'

      content.forEach (value) ->
        sublistItem = document.createElement "li"
        sublistItem.classList.add 'list-item'

        left = document.createElement 'span'
        left.classList.add 'left-col'
        left.innerHTML = "#{value.formattedTime}:"

        right = document.createElement 'span'
        right.classList.add 'right-col'
        right.innerHTML = "#{value.value}"

        sublistItem.appendChild left
        sublistItem.appendChild right
        sublist.appendChild sublistItem

      itemWrapper.appendChild item
      itemWrapper.appendChild sublist

      @element = if content.length > 0 then itemWrapper else item
      itemWrapper.addEventListener 'click', () =>
        @onClick itemWrapper

    onClick: (self) ->
      if self.classList.contains 'collapsed'
        self.classList.remove 'collapsed'

      else
        self.classList.add 'collapsed'

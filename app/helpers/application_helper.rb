module ApplicationHelper

  

  def html_block(tag)
    render({ :partial => 'page_block/html_block',
             :locals =>
              { :tag => tag,
                :page_block => @html_blocks[tag],
                :origin_controller => controller_name,
                :origin_action => action_name
              }
          })
  end

  def file_to_url(filename)
    if filename
      filename.sub(/.*public/, "")
    else
      ""
    end
  end

  def svg_symbol(id, options={})
    content_tag(:svg, options) do
      content_tag(:use, nil, :'xlink:href' => asset_path('symbols.svg') + id)
    end
  end

  # ripped off from
  # http://wiki.rubyonrails.org/rails/pages/CategoryTreeUsingActsAsTree
  def display_categories(categories, parent_id, expanded=false, &block)
    ret = "<ul>\n"
      for category in categories
        if category.parent_id == parent_id
          ret << "<li#{' class="expanded"' if expanded}>"
          ret << yield(category)
          ret << display_categories(category.children, category.id, expanded, &block) if category.children.any?
          ret << "</li>"
        end
      end
    ret << "</ul>\n"
  end

  def deeds_for(options={})
    limit = options[:limit] || 20

    condition = [String.new]

    if options[:types]
      types = options[:types]
      types = types.map { |t| "'#{t}'"}
      condition[0] = "deed_type IN (#{types.join(',')})"
    end

    if options[:user_id]
      condition[0] << " AND " unless condition[0].length == 0
      condition[0] << "user_id = ?"
      condition << options[:user_id]
    end

    if options[:not_user_id]
      condition[0] << " AND " unless condition[0].length == 0
      condition[0] << "user_id != ?"
      condition << options[:not_user_id]
    end

    if options[:collection]
      deeds = @collection.deeds.where(condition).order('created_at DESC').limit(limit)
    else
      condition[0] << " AND " unless condition[0].length == 0
      condition[0] << "collections.restricted = 0"
      deeds = Deed.includes(:collection).where(condition).order('created_at DESC').limit(limit).references(:collection)
    end

    render({ :partial => 'deed/deeds', :locals => { :limit => limit, :deeds => deeds, :options => options } })
  end

  def validation_summary(errors)
    if errors.is_a?(Enumerable) && errors.any?
      render({ :partial => 'shared/validation_summary', :locals => { :errors => errors } })
    end
  end

  def page_title(title=nil)
    base_title = 'FromThePage'

    if title.blank?
      base_title
    else
      current_page?('/') ? title : "#{title.squish} | #{base_title}"
    end
  end

end
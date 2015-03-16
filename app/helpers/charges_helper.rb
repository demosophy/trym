module ChargesHelper

  def stop_order_charge_ids
    current_user.charges.joins(:stop_orders).pluck(:id)
  end

  def merchant_name_example_helper(trym_category_id)
    if trym_category_id.present?
      merchant_names = TrymCategory.find(trym_category_id).merchants.limit(2).pluck(:name)
      merchant_names.present? ? merchant_names.join(', ') + ', ect.' : "search for company"
    else
      "Comcast, Geico, Gold's Gym, ect."
    end
  end

  def time_to_next_bill(next_billing_date)
    if next_billing_date == Date.today
      "due today"
    else
      "next charge in " +  (distance_of_time_in_words next_billing_date.to_time - Time.now.beginning_of_day)
    end
  end

  def billing_interval_in_words(renewal_period_in_weeks)
    interval = Charge.renewal_period_in_words[renewal_period_in_weeks]
    interval.present? ? interval.split(" - ").first : "#{renewal_period_in_weeks}-Weekly"
  end

  def charge_attribute_edit_link(charge, attribute, &block)
    link_to edit_charge_path(id: charge.id, attribute: attribute), class: "charge-mini-edit-link", remote: true, data:{placement: tooltip_placement_for(attribute)}, &block
  end

  def tooltip_placement_for(attribute)
    ["amount", "renewal_period_in_weeks"].include?(attribute) ? "left" : "right"
  end

  def attribute_input_value(charge, attribute)
    case attribute
    when "merchant" then nil
    when "amount" then number_to_currency(charge.amount / 100.0, precision: 2)
    when "billing_day" then charge.next_billing_date.present? ? charge.next_billing_date : charge.billing_day
    else 
      charge.send(attribute)
    end
  end

  def formatted_history(history)
    if history.present?
      "<div class='charge-history-container'>" +
      "<div class='strong charge-history-left'>2 Yr Total:</div><div class='strong charge-history-right'>#{number_to_currency history.values.inject(0.0){ |s,v| s+= v.to_f }}</div>" +
      history.to_a.reverse.collect{ |d,v| "<div><div class='charge-history-left'>#{d}:</div><div class='charge-history-right'>#{number_to_currency v.to_f}</div>" }.join("</div>")+
      "</div>"

    else
      nil
    end
  end

end

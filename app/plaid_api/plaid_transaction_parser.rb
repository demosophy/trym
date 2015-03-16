class PlaidTransactionParser
  attr_reader :charge_list

  def initialize(transaction_request_id)
    @transaction_request = TransactionRequest.find(transaction_request_id)
    @link = @transaction_request.linked_account
    create_charge_list
    parse 
  end

  def parse
    group_charges_by_description
    match_to_merchants
    # remove_old_charges
    remove_zero_dollar_charges
    calculate_recurring_score
    create_attributes_for_charges
    # consolidate_by_merchant_id
    # exclude_items_below_threshold(-5)
  end

  private

  def remove_zero_dollar_charges
    @charge_list.reject!{ |c| c[:amount].inject(:+) <= 0 }
  end

  def exclude_items_below_threshold(threshold)
    @charge_list.reject!{ |c| c[:recurring_score] < threshold }
  end

  def create_charge_list
    @charge_list = @transaction_request.data.collect{ |t| t.collect{ |k,v| [k.to_sym,v] }.to_h }
    @charge_list = (@transaction_request.previous_transactions + @charge_list).uniq{ |c| c[:_id] }
  end

  def create_attributes_for_charges
    @charge_list.each do |charge|
      charge[:history] = charge[:date].zip(charge[:amount]).sort_by{ |d,v| d }.to_h
      charge[:amount] = charge[:history][charge[:history].keys.max]
      charge[:billing_day] = charge[:date].max
      charge[:renewal_period_in_weeks] = (charge[:date].size > 1 && charge[:date].sort[-1] - charge[:date].sort[-2] > 180) ? 52 : 4
    end
  end

  def average_amount_of_recent_transactions(charge)
    num_items = charge[:history].size > 3 ? 3 : charge[:history].size
    (charge[:history].values[-num_items..-1].inject(:+) / num_items.to_f * 100).to_i
  end

  def group_charges_by_description
    completed_list = []
    grouped_list = []

    @charge_list.each do |item|
      charge = item.deep_dup
      next if completed_list.include?(charge[:name])
      completed_list << charge[:name]      
      charge[:amount] = []
      charge[:date] = []
      
      @charge_list.each do |sibling| 
        if charge[:name].present?
          if charge[:name] == sibling[:name]
            charge[:amount] << sibling[:amount]
            charge[:date] << Date.parse(sibling[:date])
            completed_list << sibling[:name]
          end
        end
      end
      grouped_list << charge
    end
    @charge_list = grouped_list
  end

  def remove_old_charges
    @charge_list.reject! do |c|
      dates = c[:date].sort
      dates.max < 12.months.ago && avg_distance_between_last_four_dates(dates).between?(350,380)
    end
  end

  def calculate_recurring_score
    @charge_list.map do |c|
      c[:recurring_score] = TransactionScorer.new(c, @transaction_request).calculate_recurring_score
      c[:recurring] = true if ( c[:recurring_score] > 4 && c[:merchant_id].present? )
    end
  end

  def consolidate_by_merchant_id
    sorted_list = @charge_list.sort_by{ |x| x[:recurring_score] }.reverse
    no_merch = sorted_list.select{ |c| c[:merchant_id].nil? }
    with_merch = sorted_list.uniq{ |c| c[:merchant_id] }
    
    (@charge_list - with_merch).each do |c|
      if c[:merchant_id].present?
        index = with_merch.index(with_merch.select{ |x| x[:merchant_id] == c[:merchant_id] }.first)
        with_merch[index][:amount] << c[:amount]
        with_merch[index][:date] << c[:date]
        with_merch[index][:history] = with_merch[index][:history].merge(c[:history])
      end
    end

    @charge_list = (no_merch + with_merch).uniq{ |c| c[:name] }
  end

  def match_to_merchants
    @charge_list.map do |c|
      match = Merchant.find_by_fuzzy_name_with_similar_threshold(c[:name])
      if ( !match.present? && c[:meta]["payment_processor"].present? )
        match = Merchant.find_by_fuzzy_name_with_similar_threshold(c[:meta]["payment_processor"]) if c[:meta]["payment_processor"].present?
      elsif ( !match.present? && card_membership_fees.select{ |n| c[:name].downcase.include?(n) }.present? && c[:category_id] == "10000000" )
        match = Merchant.find_by_fuzzy_name_with_similar_threshold(@link.financial_institution.name)
      end
      c[:merchant_id] = match.id if match.present?
    end
  end

  def card_membership_fees
    ["annual membership"]
  end
end
class ChargeBuilder

	def initialize(transaction_request)
		@transaction_request = transaction_request
		@user_id = transaction_request.linked_account.user.id
		create_charges
	end

	def create_charges
		charges = PlaidTransactionParser.new(@transaction_request.id).charge_list
		if charges.present?
			charges.each do |charge|
				unless is_not_charge?(charge)
					old_charge = existing_charge(charge)
					if old_charge.present?
						old_charge.update!(sanitize_charge_params_for_update(charge, old_charge))
					else
						#Do not add the charge if there's already a charge with the same description on that linked account
						Charge.create!(sanitize_charge_params(charge))
					end
				end
			end
		end
	end

	def existing_charge(charge)
		if charge[:merchant_id].present?
			Charge.where( merchant_id: charge[:merchant_id], linked_account_id: @transaction_request.linked_account.id ).first
		else
			Charge.where( plaid_name: charge[:name], linked_account_id: @transaction_request.linked_account.id ).first
		end
	end

	def is_not_charge?(charge)
		charge[:amount] < 0
	end

	def sanitize_charge_params(charge)
		{
			amount: (charge[:amount] * 100).to_i,
			billing_day: charge[:billing_day],
			category_id: charge[:category_id],
			recurring_score: charge[:recurring_score],
			plaid_name: charge[:name],
			merchant_id: charge[:merchant_id],
			renewal_period_in_weeks: charge[:renewal_period_in_weeks],
			user_id: @user_id,
			transaction_request_id: @transaction_request.id,
			linked_account_id: @transaction_request.linked_account.id,
			history: charge[:history]
		}
	end

	def sanitize_charge_params_for_update(charge, old_charge)
		{
			amount: (charge[:amount] * 100).to_i,
			billing_day: charge[:billing_day],
			transaction_request_id: @transaction_request.id,
			linked_account_id: @transaction_request.linked_account.id,
			history: old_charge.history.merge(charge[:history])
		}
	end
end
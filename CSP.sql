SELECT billing_month
      --submit the output of the next three lines into the form
      ,hash_id
      ,FORMAT('$%,.2f',charges) AS charges
      ,ROUND((1-(1.0*net_cost/charges))*100,2) AS cloud_savings_pct
FROM (
SELECT CONCAT(year,'-',LPAD(month,2,'0')) AS billing_month
      ,TO_BASE64(hmac_sha256(TO_UTF8(UPPER(TRIM(bill_payer_account_id))),CAST(CAST(bill_payer_account_id AS VARCHAR) AS VARBINARY))) AS hash_id
      ,CAST(SUM(CASE
                    WHEN line_item_line_item_type NOT IN ('Fee','SavingsPlanUpfrontFee','EdpDiscount','PrivateRateDiscount','RiVolumeDiscount'
                                                         ,'BundledDiscount','SavingsPlanNegation','Credit','Tax') THEN line_item_unblended_cost
                    ELSE 0 
       END) AS DECIMAL(17,2)) AS charges
      ,CAST(SUM(CASE WHEN line_item_line_item_type IN ('Usage') AND line_item_product_code != 'AWSSupportEnterprise' THEN line_item_net_unblended_cost ELSE 0 END) --Usage
      + SUM(CASE WHEN line_item_line_item_type = 'SavingsPlanCoveredUsage' THEN savings_plan_net_savings_plan_effective_cost ELSE 0 END) --SavingsPlanCoveredUsage
      + SUM(CASE WHEN line_item_line_item_type IN ('SavingsPlanRecurringFee') THEN (
                 CASE WHEN savings_plan_payment_option IN ('No Upfront', 'Partial Upfront') THEN 
                           COALESCE(savings_plan_net_recurring_commitment_for_billing_period, 1) / COALESCE(savings_plan_recurring_commitment_for_billing_period, 1)
                      WHEN savings_plan_payment_option = 'All Upfront' THEN 
                           COALESCE(savings_plan_net_amortized_upfront_commitment_for_billing_period, 1) / COALESCE(savings_plan_amortized_upfront_commitment_for_billing_period, 1)
                      END * (savings_plan_total_commitment_to_date-savings_plan_used_commitment))END) --SavingsPlanRecurringFee
      + SUM(CASE WHEN line_item_line_item_type != 'Tax' AND line_item_product_code IN ('AWSSupportEnterprise') THEN line_item_net_unblended_cost ELSE 0 END) --SupportFee
      + SUM(CASE WHEN line_item_line_item_type = 'Tax' THEN line_item_net_unblended_cost ELSE 0 END) --Tax
      + SUM(CASE WHEN line_item_line_item_type = 'DiscountedUsage' THEN reservation_net_effective_cost ELSE 0 END) --ReservationAppliedUsage
      + SUM(CASE WHEN line_item_line_item_type != 'Tax' AND line_item_product_code LIKE 'OC%' THEN line_item_net_unblended_cost ELSE 0 END) --OtherOOCCharges
      + SUM(CASE WHEN line_item_line_item_type = 'RIFee' THEN (reservation_net_unused_amortized_upfront_fee_for_billing_period+reservation_net_unused_recurring_fee) ELSE 0 END) --RecurringReservationFee
      + SUM(CASE WHEN line_item_line_item_type = 'BundledDiscount' THEN line_item_net_unblended_cost ELSE 0 END) --BundledDiscount
      + SUM(CASE WHEN line_item_line_item_type = 'EdpDiscount' THEN line_item_net_unblended_cost ELSE 0 END) --EdpDiscount
      + SUM(CASE WHEN line_item_line_item_type = 'PrivateRateDiscount' THEN line_item_net_unblended_cost ELSE 0 END) --PrivateRateCard
      + SUM(CASE WHEN line_item_line_item_type = 'SavingsPlanNegation' THEN line_item_net_unblended_cost ELSE 0 END) --SavingsPlanNegation
      + SUM(CASE WHEN line_item_line_item_type = 'RIFee' THEN reservation_net_amortized_upfront_cost_for_usage ELSE 0 END) --UpfrontReservationFee
      AS DECIMAL(17,2)) AS net_cost
  FROM cur
 WHERE bill_billing_entity = 'AWS'
   AND year = '2024' AND month = '4'
 GROUP BY 1,2)

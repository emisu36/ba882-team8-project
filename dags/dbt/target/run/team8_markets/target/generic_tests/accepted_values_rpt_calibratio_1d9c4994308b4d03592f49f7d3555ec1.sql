
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        prob_bin as value_field,
        count(*) as n_records

    from `ba882-team8-fall26`.`mart`.`rpt_calibration`
    group by prob_bin

)

select *
from all_values
where value_field not in (
    0,1,2,3,4,5,6,7,8,9
)



  
  
      
    ) dbt_internal_test
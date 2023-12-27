
# Import necessary modules.
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.serialize import serialize_word
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.squash_dict import squash_dict
from starkware.cairo.common.alloc import alloc

# Define a KeyValue structure.
struct KeyValue:
    member key: felt
    member value: felt
end

# Function to build a dictionary.
func build_dict(list: KeyValue*, size, dict: DictAccess*) -> (dict: DictAccess*):
    alloc_locals

    if size == 0:
        return (dict=dict)
    end

    %{
        key = ids.list.key
        prev_value = ids.list.value
        ids.dict.key = ids.list.key

        if len(cumulative_sums) == 0:
            cumulative_sums.update({key: ids.list.value})
            ids.dict.prev_value = 0
            ids.dict.new_value = ids.list.value
        elif ids.list.key in cumulative_sums.keys():
            x = cumulative_sums.get(key)
            ids.dict.prev_value = x
            new_value = x + ids.list.value
            cumulative_sums.update({key: new_value})
            ids.dict.new_value = cumulative_sums.get(key)
        else:
            cumulative_sums.update({key: ids.list.value})
            ids.dict.prev_value = 0
            ids.dict.new_value = ids.list.value
    %}

    assert dict.new_value = dict.prev_value + list.value

    # Call build_dict recursively.
    return build_dict(
       list=list + KeyValue.SIZE,
       size=size - 1,
       dict=dict + DictAccess.SIZE
    )
end

# Function to verify and output a squashed dictionary.
func verify_and_output_squashed_dict(
    squashed_dict: DictAccess*,
    squashed_dict_end: DictAccess*,
    result: KeyValue*
) -> (result: KeyValue*):
    tempvar diff = squashed_dict_end - squashed_dict
    if diff == 0:
        return(result=result)
    end

    assert squashed_dict.prev_value = 0
    assert result.key = squashed_dict.key
    assert result.value = squashed_dict.new_value

    return verify_and_output_squashed_dict(
        squashed_dict=squashed_dict + DictAccess.SIZE,
        squashed_dict_end=squashed_dict_end,
        result=result + KeyValue.SIZE
    )
end

# Function to  values by key.
func sum_by_key{range_check_ptr}(list: KeyValue*, size) -> (result: KeyValue*, result_size):
    alloc_locals

    %{
        cumulative_sums = {}
    %}

    let (local dict_start: DictAccess*) = alloc()
    let (local squashed_dict: DictAccess*) = alloc()
    let (local result: KeyValue*) = alloc()
    local result_size

    let (local dict_end: DictAccess*) = build_dict(
        list=list,  # Input list.
        size=size,  # Size of the input list.
        dict=dict_start
    )

    let (squashed_dict_end: DictAccess*) = squash_dict(
        dict_accesses=dict_start,
        dict_accesses_end=dict_end,
        squashed_dict=squashed_dict,
    )

    let(result) = verify_and_output_squashed_dict(
        squashed_dict=squashed_dict,
        squashed_dict_end=squashed_dict_end,
        result=result
    )

    assert result_size = (squashed_dict_end - squashed_dict) / DictAccess.SIZE

    %{
        print(f"Result size = {ids.result_size}")
    %}

    return (result=result, result_size=result_size)
end

# Main function.
func main{output_ptr: felt*, range_check_ptr}():
    alloc_locals

    # Define an input list and size.
    local list: KeyValue*
    local size: felt

    # Define KeyValue tuples.
    local KeyValue_tuple: (
        KeyValue, KeyValue, KeyValue, KeyValue, KeyValue
    ) = (
        KeyValue(key=3, value=5),
        KeyValue(key=1, value=10),
        KeyValue(key=3, value=1),
        KeyValue(key=3, value=8),
        KeyValue(key=1, value=20),
    )

    # Get the value of the frame pointer register (fp) to use the address of loc_tuple Loc0.
    let (__fp__, _) = get_fp_and_pc()

    let (result, result_size) = sum_by_key(list=cast(&KeyValue_tuple, KeyValue*), size=5)

    return ()
    
    # Prompt the user to enter the size of the input list.
  size = input("Enter the size of the input list: ")
  size = int(size)

  # Initialize an empty list to store key-value pairs.
  input_list = []

  # Read key-value pairs from the user.
  for i in range(size):
    key = input(f"Enter key for pair {i + 1}: ")
    value = input(f"Enter value for pair {i + 1}: ")
    input_list.append(KeyValue(key=int(key), value=int(value)))

  # Sort the result by key.
  result = sorted(result, key=lambda x: x.key)
  
  # Prompt the user to enter a key for filtering.
filter_key = input("Enter a key for filtering: ")
filter_key = int(filter_key)

# Filter the result by the specified key.
filtered_result = [item for item in result if item.key == filter_key]

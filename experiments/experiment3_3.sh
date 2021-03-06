# Script for Experiment 3.3
echo "Starting Experiment 3.3"

experiment="3.3"
# the paper this experiment is being run for
paper="assets-2022"
# city names
cities=("city1" "city2" "city3" "city4" "city5")
# subset portions of city of interest to include for training
subsets=("0.1" "0.2" "0.3")
# label types
labels=("curb_ramp" "missing_curb_ramp" "obstacle" "surface_problem")
# path to train/test CSV data
csv_base_path="../datasets/"
# train set CSV filename
train_set_csv="train_set.csv"
# test set CSV filename
test_set_csv="test_set.csv"
# path to train/test image data
image_base_path="/mnt/disks/shared-disk/crops/"
# name of model architecture
model_name="hrnet"
# save path for model weights
model_save_folder="../models/"
# save path the visualizations
visualizations_path="../visualizations/"
# number of epochs for training
num_epochs="10"
# crop size
crop_size="1000"
# number of plots for mistake visualization
num_plots="5"

echo "initializing..."
# make binarized train and test sets for each city
for city in ${cities[@]}; do
  mkdir -p $csv_base_path/"tmp/"$city
  for label in {1..4}; do
    python ../utils/dataset_creator.py "binarize" "$csv_base_path/$paper/$city/$train_set_csv" "$label" "$csv_base_path/tmp/$city/train_set_${labels[$label - 1]}.csv"
    python ../utils/dataset_creator.py "binarize" "$csv_base_path/$paper/$city/$test_set_csv" "$label" "$csv_base_path/tmp/$city/test_set_${labels[$label - 1]}.csv"
  done
done

for subsetted_city in ${cities[@]}; do
  for subset in ${subsets[@]}; do
    # make relevant directories
    mkdir -p "$csv_base_path/tmp/subset_$subsetted_city/$subset/"
    mkdir -p "$model_save_folder/$experiment/subset_$subsetted_city/$subset/"
    mkdir -p "$visualizations_path/$experiment/$subsetted_city/$subset/"
    
    for label in {1..4}; do
      echo "training label ${labels[$label - 1]} classifier on all cities with a $subset subset of $subsetted_city..."
      # combine subset of city of interest with full train sets of all other cities
      arguments=""
      for city in ${cities[@]}; do
        if [ $city == $subsetted_city ]; then
          dataset_size=$(($(wc $csv_base_path/tmp/$city/train_set_${labels[$label - 1]}.csv | awk '{print $1}') - 1))
          subset_size=$(echo $subset*$dataset_size | bc)
          python ../utils/dataset_creator.py "subset" "$csv_base_path/tmp/$city/train_set_${labels[$label - 1]}.csv" "$subset_size" "$csv_base_path/tmp/subset.csv"
          arguments+="$csv_base_path/tmp/subset.csv "
        else
          arguments+="$csv_base_path/tmp/$city/train_set_${labels[$label - 1]}.csv "
        fi
      done
      python ../utils/dataset_creator.py "combine" "$arguments" "$csv_base_path/tmp/subset_$subsetted_city/$subset/train_set_${labels[$label - 1]}.csv"
      rm "$csv_base_path/tmp/subset.csv"

      # train model on combined train set
      python ../train.py "${experiment}_${model_name}_${labels[$label - 1]}" "$image_base_path/" "$csv_base_path/tmp/subset_$subsetted_city/$subset/train_set_${labels[$label - 1]}.csv" "$model_name" "$model_save_folder/$experiment/subset_$subsetted_city/$subset/" "$num_epochs" "$crop_size"

      echo "testing label ${labels[$label - 1]} classifier on $subsetted_city..."
      # evaluate model on subsetted city
      python ../eval.py "${experiment}_${model_name}_${labels[$label - 1]}" "$image_base_path/" "$csv_base_path/tmp/$subsetted_city/test_set_${labels[$label - 1]}.csv" "$model_name" "$model_save_folder/$experiment/subset_$subsetted_city/$subset/" "$visualizations_path/$experiment/$subsetted_city/$subset/" "$crop_size"
      # analyze results
      python ../visualization_utils/analyze_results.py "${experiment}_${model_name}_${labels[$label - 1]}" "$model_save_folder/$experiment/subset_$subsetted_city/$subset/" "$visualizations_path/$experiment/$subsetted_city/$subset/"
      # visualize mistakes
      python ../visualization_utils/visualize_mistakes.py "${experiment}_${model_name}_${labels[$label - 1]}" "$image_base_path/" "$visualizations_path/$experiment/$subsetted_city/$subset/" "$crop_size" "$num_plots"
    done
  done
done

echo "Finished Experiment 3.3!"

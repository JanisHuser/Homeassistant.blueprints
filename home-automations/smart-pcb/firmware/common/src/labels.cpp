#include "labels.h"

#include <cstring>

#include <esp_log.h>
#include <esp_matter_providers.h>

#include <lib/support/CHIPMem.h>
#include <platform/DeviceInfoProvider.h>

static const char *TAG = "labels";

using namespace esp_matter;
using chip::CharSpan;
using chip::EndpointId;
using chip::DeviceLayer::DeviceInfoProvider;

/** Root node, the product's endpoints and the diagnostics switches all fit (CONFIG_ESP_MATTER_MAX_DYNAMIC_ENDPOINT_COUNT). */
static constexpr size_t MAX_LABELS = CONFIG_ESP_MATTER_MAX_DYNAMIC_ENDPOINT_COUNT;

struct label_t {
    EndpointId endpoint;
    const char *name;
};
static label_t labels[MAX_LABELS];
static size_t label_count;

void device_label_endpoint(endpoint_t *endpoint, const char *name)
{
    if (label_count == MAX_LABELS || strlen(name) > LABEL_MAX_LENGTH) {
        ESP_LOGE(TAG, "Label \"%s\" not added (too many, or longer than %u characters)", name, static_cast<unsigned>(LABEL_MAX_LENGTH));
        return;
    }
    cluster::fixed_label::config_t config;
    if (!cluster::fixed_label::create(endpoint, &config, CLUSTER_FLAG_SERVER)) {
        ESP_LOGE(TAG, "No Fixed Label cluster for \"%s\"", name);
        return;
    }
    labels[label_count++] = {endpoint::get_id(endpoint), name};
}

/** The Fixed Label cluster's LabelList of one endpoint: its LABEL_KEY entry, if it has one. */
class FixedLabels final : public DeviceInfoProvider::FixedLabelIterator {
public:
    explicit FixedLabels(EndpointId endpoint) : endpoint_(endpoint) {}

    size_t Count() override
    {
        size_t n = 0;
        for (size_t i = 0; i < label_count; i++) {
            n += labels[i].endpoint == endpoint_;
        }
        return n;
    }

    bool Next(DeviceInfoProvider::FixedLabelType &item) override
    {
        for (; next_ < label_count; next_++) {
            if (labels[next_].endpoint == endpoint_) {
                item.label = CharSpan::fromCharString(LABEL_KEY);
                item.value = CharSpan::fromCharString(labels[next_].name);
                next_++;
                return true;
            }
        }
        return false;
    }

    void Release() override { chip::Platform::Delete(this); }

private:
    EndpointId endpoint_;
    size_t next_ = 0;
};

/** Only fixed labels: no user labels, locales or calendar types (those clusters aren't created). */
class LabelProvider final : public DeviceInfoProvider {
public:
    FixedLabelIterator *IterateFixedLabel(EndpointId endpoint) override { return chip::Platform::New<FixedLabels>(endpoint); }
    UserLabelIterator *IterateUserLabel(EndpointId endpoint) override { return nullptr; }
    SupportedLocalesIterator *IterateSupportedLocales() override { return nullptr; }
    SupportedCalendarTypesIterator *IterateSupportedCalendarTypes() override { return nullptr; }

protected:
    CHIP_ERROR SetUserLabelLength(EndpointId endpoint, size_t val) override { return CHIP_ERROR_NOT_IMPLEMENTED; }
    CHIP_ERROR GetUserLabelLength(EndpointId endpoint, size_t &val) override
    {
        val = 0;
        return CHIP_NO_ERROR;
    }
    CHIP_ERROR SetUserLabelAt(EndpointId endpoint, size_t index, const UserLabelType &userLabel) override
    {
        return CHIP_ERROR_NOT_IMPLEMENTED;
    }
    CHIP_ERROR DeleteUserLabelAt(EndpointId endpoint, size_t index) override { return CHIP_ERROR_NOT_IMPLEMENTED; }
};

static LabelProvider provider;

void labels_register()
{
    esp_matter::set_custom_device_info_provider(&provider);
}
